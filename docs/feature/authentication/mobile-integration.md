# Mobile integration: password change and reset with a Firebase SMS code

For the mobile team. This page covers what the app does for two screens:

- **Forgot password** (not signed in)
- **Change password** (signed in)

In both, Firebase sends and checks the SMS code. The backend decides whether Firebase may send it.

Background and full diagrams: `sequence-diagrams.md` ⧉ backend repo. Field-level contract:
`api-contract.md` ⧉ backend repo. Endpoint paths the app calls:
[api.md](api.md).

## Design decisions

Carried over from the original implementation plan (2026-10, since deleted):

- **Firebase proves phone ownership, nothing more.** The SteelForce backend
  validates the Firebase evidence, authorises the reset, and is the **only**
  system that validates, hashes and stores passwords.
- No user is migrated to Firebase, and no password is ever stored there. The
  app session stays the backend's access and refresh tokens.
- Phone-number-and-password sign-in must keep working unchanged.
- Mobile and backend agree on these before changing the flow: endpoint URLs and
  methods, JSON schemas, error codes, the Firebase project and phone-auth
  configuration, phone-number normalisation, reset-token expiry and single use,
  password policy, and which sessions are invalidated after a reset.

## How it works in one paragraph

The app first asks **our API** to open a verification. The API answers with the phone number to
use. The app then calls **Firebase** `verifyPhoneNumber` with exactly that number. Before Firebase
sends the SMS, it asks our API (through a Cloud Function) whether the SMS is allowed. The user
types the code, the app signs in to Firebase with it, and the app sends the resulting **Firebase ID
token** back to our API. The API returns a short-lived token that lets the user set the new
password.

```
App ──start──▶ API          (API opens a verification, returns phoneNumber)
App ──verifyPhoneNumber──▶ Firebase ──"may I send?"──▶ API ──allow/deny
User types code ──▶ App signs in to Firebase ──▶ Firebase ID token
App ──verify { firebaseIdToken }──▶ API   (returns a one-time token)
App ──set new password with that token──▶ API
```

The Firebase sign-in is used **only** to prove the phone number. The app's session is still
the backend's access and refresh tokens. The backend deletes the temporary Firebase user after each
proof.

## Before you start

| Item | Notes |
|---|---|
| Firebase SDKs | Firebase Auth (phone) and **App Check**. App Check is enforced for Authentication, so phone sign-in fails without it. |
| Firebase config | `google-services.json` / `GoogleService-Info.plist` for the right environment's project. Ask the backend team for the project of each environment. |
| Android | Add the app's SHA-1 and SHA-256 fingerprints in the Firebase console. They are needed for phone auth and Play Integrity. |
| iOS | APNs key uploaded in Firebase and push capability on. Firebase uses a silent push, or a reCAPTCHA fallback, to verify the app. |
| SMS region | Only Cambodian numbers (`KH`) are allowed. |
| Backend | Works only when the API runs with `PASSWORD_RESET_PHONE_CHANNEL=Firebase`. Otherwise the start endpoints return `400 AUTH_PHONE_CHANNEL_DISABLED`. |

All API responses use the usual envelope: `{ "success": true, "data": … }` on success and
`{ "success": false, "error": { "code", "message", "traceId", "details" } }` on error. The
examples below show only `data`.

---

## Flow A: Forgot password (not signed in)

### A1. Start

```http
POST /api/v1/auth/forgot-password/phone/start
Content-Type: application/json

{ "phoneNumber": "012 345 678" }
```

The number can be local (`012 345 678`) or E.164 (`+85512345678`).

`200`:

```json
{
  "message": "If an account exists, you can now request the SMS code.",
  "phoneNumber": "+85512345678",
  "expiresIn": 300,
  "resendAfter": 60
}
```

- The answer is **the same whether or not the number has an account.** Never tell the user that
  a number is unknown.
- `phoneNumber` is the E.164 number. Pass **exactly this value** to Firebase in the next step.
- `expiresIn`: seconds the user has to receive and enter the code (5 minutes by default).
- `resendAfter`: seconds before the user may ask again. Use it to disable the resend button.

### A2. Ask Firebase to send the SMS

Call `verifyPhoneNumber(data.phoneNumber)`.

- **The code is sent** (`codeSent`): keep the `verificationId` and show the code entry screen.
- **Firebase reports an error:** show the **same neutral text** as on success: *"If an account
  exists, a code has been sent."* This is what happens for a number without an account: our gate
  refuses the SMS and Firebase returns an error. Log the error code for debugging, but do not show
  "number not found".
- **Android auto-verification** (`verificationCompleted`): use that credential directly in A3.

### A3. Sign in to Firebase with the code, and get the ID token

Build the credential from `verificationId` and the code the user typed, then sign in. Then get a
fresh ID token with `getIdToken(true)`.

A wrong code fails here, in Firebase. Let the user retry the code. Don't call the API yet.

### A4. Trade the Firebase proof for a reset token

```http
POST /api/v1/auth/forgot-password/phone/verify
Content-Type: application/json

{ "firebaseIdToken": "eyJhbGciOi…" }
```

`200`:

```json
{
  "resetToken": "…",
  "expiresIn": 600,
  "passwordPolicy": {
    "minLength": 12, "maxLength": 64,
    "requireUppercase": true, "requireLowercase": true,
    "requireNumber": true, "requireSpecial": true
  }
}
```

Sign out of Firebase now (`FirebaseAuth.signOut()`). Use `passwordPolicy` to validate the new
password on screen.

`401 AUTH_PHONE_PROOF_INVALID` is the **only** refusal code. It covers a wrong number, an expired
verification, a reused proof, and a number without an account. Ask the user to start again
from A1.

### A5. Set the new password

This is the existing endpoint, unchanged:

```http
POST /api/v1/auth/forgot-password/reset
Content-Type: application/json

{ "resetToken": "…", "newPassword": "…", "confirmPassword": "…" }
```

`200` with `{ "message": "…" }`. **All sessions of the user are ended.** Send the user to the
sign-in screen.

- **The password fails the policy (`400`):** the reset token stays valid, so the user can try
  again.
- **`401 AUTH_RESET_TOKEN_INVALID`:** the token expired or was already used. Start again from A1.

---

## Flow B: Change password (signed in)

The user does **not** type the current password. An SMS to the account's own number proves who
they are. All calls send `Authorization: Bearer <accessToken>`. They also work while a temporary
password is pending (`passwordChangeRequired: true`).

### B1. Start

```http
POST /api/v1/auth/password/phone/start
Authorization: Bearer <accessToken>
```

No body: the number always comes from the account, never from the app.

`200`: `{ "message": "…", "phoneNumber": "+85512345678", "expiresIn": 300, "resendAfter": 60 }`

Errors:
- **`400 AUTH_PHONE_NUMBER_REQUIRED`:** the account has no phone number. Show *"Ask an
  administrator to add your phone number."*
- **`429 AUTH_RESET_REQUEST_LIMIT_EXCEEDED`:** see [Limits](#limits-and-resend).

You can show the user a masked number (`+855 •• ••• 678`) so they know where the code goes.

### B2–B3. Firebase

Same as A2 and A3. For this flow the SMS should always be allowed. If Firebase still reports an
error, show *"Could not send the code. Try again later."*

### B4. Trade the Firebase proof for a phone proof token

```http
POST /api/v1/auth/password/phone/verify
Authorization: Bearer <accessToken>
Content-Type: application/json

{ "firebaseIdToken": "eyJhbGciOi…" }
```

`200`: `{ "phoneProofToken": "…", "expiresIn": 300 }`

The token works once and lasts 5 minutes. Sign out of Firebase now.
`401 AUTH_PHONE_PROOF_INVALID`: start again from B1.

### B5. Set the new password

```http
POST /api/v1/mobile/auth/change-password
Authorization: Bearer <accessToken>
Content-Type: application/json

{ "phoneProofToken": "…", "newPassword": "…" }
```

`204 No Content`. **This device stays signed in**; the user's other sessions are ended.

Send **exactly one** of `phoneProofToken` and `currentPassword`.

| Error | Meaning |
|---|---|
| `400 USER_PASSWORD_TOO_WEAK` (or another `400` validation error) | The password fails the policy. The proof token stays valid, so let the user try again. |
| `400 AUTH_PASSWORD_CHANGE_PROOF_REQUIRED` | Neither `phoneProofToken` nor `currentPassword` was sent. |
| `401 AUTH_PHONE_PROOF_INVALID` | The token is unknown, already used, expired, or belongs to another user. Start again from B1. |

---

## Limits and resend

- **One SMS per verification.** To resend, call **start again** (A1 or B1) after `resendAfter`
  seconds, then call `verifyPhoneNumber` again. **Do not use Firebase's own resend**
  (`forceResendingToken`): our gate refuses a second SMS for the same verification.
- **Limits per number:**
  - cooldown between starts: 60 s by default
  - starts per hour: 5 by default
  - starts per day: 10 by default
- **Over a limit** you get `429 AUTH_RESET_REQUEST_LIMIT_EXCEEDED`. The wait is in
  `error.details.retryAfterSeconds` and in the `Retry-After` header. Show a countdown.
- **Use the ID token right away.** The API checks Firebase's sign-in time against the
  verification's 5-minute window. Always call `getIdToken(true)` right after signing in, and call
  verify immediately.

## Error codes the app should handle

| Code | HTTP | Where | What to show |
|---|---|---|---|
| `AUTH_PHONE_CHANNEL_DISABLED` | 400 | start | "This feature is not available. Please update the app." |
| `AUTH_PHONE_NUMBER_REQUIRED` | 400 | B1 | "Ask an administrator to add your phone number." |
| `AUTH_RESET_REQUEST_LIMIT_EXCEEDED` | 429 | start | "Too many requests. Try again in {retryAfterSeconds}." |
| `AUTH_PHONE_PROOF_INVALID` | 401 | verify, B5 | "Verification failed or expired. Request a new code." |
| `AUTH_RESET_TOKEN_INVALID` | 401 | A5 | "Your reset session expired. Start again." |
| `AUTH_PASSWORD_CHANGE_PROOF_REQUIRED` | 400 | B5 | App bug: send `phoneProofToken`. |
| `USER_PASSWORD_TOO_WEAK` / `VALIDATION_FAILED` | 400 | A5, B5 | The policy message; keep the token and let the user retry. |
| (any) | 429 without a code | any | General rate limit. Wait and retry. |

Always log `error.traceId`. The backend team can find the request in the logs and the audit trail
by it.

## Example (Flutter)

This is a sketch only. Native Android (`PhoneAuthProvider.verifyPhoneNumber(PhoneAuthOptions)`)
and iOS (`PhoneAuthProvider.provider().verifyPhoneNumber`) follow the same steps.

```dart
// A1 or B1: the API returns the number to use.
final start = await api.startForgotPassword(phoneInput);  // or api.startOwnPhoneVerification()
final phone = start.phoneNumber;                           // "+85512345678"

// A2: ask Firebase to send the SMS.
await FirebaseAuth.instance.verifyPhoneNumber(
  phoneNumber: phone,
  timeout: const Duration(seconds: 60),
  verificationCompleted: (credential) async => _finish(credential), // Android auto-verify
  verificationFailed: (e) {
    log('firebase phone error: ${e.code}');
    showNeutralMessage();          // forgot password: same text as on success
  },
  codeSent: (verificationId, _) => openCodeScreen(verificationId), // ignore resendToken
  codeAutoRetrievalTimeout: (_) {},
);

// A3: after the user enters the code.
Future<void> onCodeEntered(String verificationId, String code) =>
    _finish(PhoneAuthProvider.credential(verificationId: verificationId, smsCode: code));

Future<void> _finish(PhoneAuthCredential credential) async {
  final user = (await FirebaseAuth.instance.signInWithCredential(credential)).user!;
  final idToken = await user.getIdToken(true);
  try {
    // A4 → resetToken, or B4 → phoneProofToken.
    final proof = await api.verifyForgotPassword(idToken);
    openNewPasswordScreen(proof);
  } finally {
    await FirebaseAuth.instance.signOut(); // the Firebase session is not the app session
  }
}
```

## Testing

- **Known number** (an active account with this phone): the SMS arrives, verify returns a token,
  and the password changes.
- **Unknown number:** start returns `200`, Firebase reports an error, no SMS is sent, and the app
  shows the neutral text.
- **Resend:** wait `resendAfter`, then start again. A new SMS arrives.
- **Expired:** wait more than 5 minutes after start before verifying → `401
  AUTH_PHONE_PROOF_INVALID`.
- **Weak password at the last step:** `400`; then a valid password with the **same** token
  succeeds.
- **Firebase test phone numbers** (console → Authentication → Phone → test numbers) send no real
  SMS. Firebase may then skip our gate, and the API accepts a proof only after the gate allowed
  the SMS. Expect test numbers to fail at verify. Test with real SIM cards on the dev project.

Questions about the API: the backend team. Each error's `traceId` helps them find it.
