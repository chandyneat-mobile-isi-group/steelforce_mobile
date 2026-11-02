# Forgot Password with Firebase OTP: Mobile Integration Guide

> **Not the contract the app uses (rechecked 2026-10-22, afternoon).** Staging
> (`www.pnc-spts-stg-api.me`) now serves the `/auth/forgot-password/phone/start` →
> `/phone/verify` → `/auth/forgot-password/reset` contract in
> [mobile-integration.md](mobile-integration.md), and the app calls those. The
> `/mobile/auth/verify-firebase-phone` and `/mobile/auth/reset-password` routes below
> now answer `401 AUTH_UNAUTHENTICATED` to an anonymous call. Kept for reference.

**For:** Flutter (mobile app) developers
**Backend status:** implemented 2026-10-21. No database migration.
**Firebase project:** `steelforce-94963`

This guide covers only what the app has to do. Firebase sends and checks the SMS code. The SteelForce backend checks Firebase's proof, then changes the password.

---

## 1. The flow in one picture

```
 App                              Firebase                     SteelForce API
  │ verifyPhoneNumber(+855…) ───────►│
  │◄──────────────── SMS code ───────│
  │ signInWithCredential(code) ─────►│
  │◄────────────── Firebase user ────│
  │ getIdToken()                     │
  │                                                                │
  │ ① POST /mobile/auth/verify-firebase-phone { firebaseIdToken } ►│  checks token, finds account
  │◄──────────────────────────── { verificationId, expiresIn:300 } │
  │                                                                │
  │ ② POST /mobile/auth/reset-password { verificationId, newPassword } ►│  sets password, signs out every device
  │◄──────────────────────────────────────────────────────── 204   │
  │                                                                │
  │ FirebaseAuth.signOut()  →  back to the normal login screen     │
```

Firebase is used **only for this flow**. Login stays the same: `POST /api/v1/auth/token` with employee ID or e-mail and password. Do not send a Firebase token to any other endpoint.

---

## 2. Endpoints

Base URL: `{API_BASE}/api/v1/mobile/auth`

| # | Method & path | Auth | Use |
|---|---|---|---|
| ① | `POST /verify-firebase-phone` | **None** (anonymous) | Exchange the Firebase ID token for a `verificationId` |
| ② | `POST /reset-password` | **None** (anonymous) | Set the new password using that `verificationId` |

Headers for both:

```
Content-Type: application/json
Accept-Language: en-US | km-KH        (optional)
```

Do **not** send a SteelForce `Authorization` header. The user can't log in, which is why they're resetting.

> The older endpoints `forgot-password`, `verify-reset-code` and `resend-reset-code` are for SMS sent by the backend. **Do not call them in the Firebase flow.** Firebase replaces them.

---

### ① `POST /verify-firebase-phone`

**Request**

```json
{
  "firebaseIdToken": "eyJhbGciOiJSUzI1NiIsImtpZCI6Ij..."
}
```

Send only the token. **Do not send the phone number.** The backend reads the number from the token's verified `phone_number` claim and ignores anything else.

**200 OK**

```json
{
  "data": {
    "verificationId": "0199a1b2-c3d4-7e5f-8a9b-0c1d2e3f4a5b",
    "expiresIn": 300
  },
  "meta": { "correlationId": "0HNOKIT2F0GAT:00000001" }
}
```

| Field | Meaning |
|---|---|
| `verificationId` | Send this to step ②. Works **once**. Keep it in memory only. Don't persist or log it. |
| `expiresIn` | Seconds until it expires (**300 = 5 minutes**). After that, the user has to verify their phone again. |

### ② `POST /reset-password`

**Request**

```json
{
  "verificationId": "0199a1b2-c3d4-7e5f-8a9b-0c1d2e3f4a5b",
  "newPassword": "N3w-Passw0rd!"
}
```

**204 No Content**: success, with an empty body. Then:

1. Call `FirebaseAuth.instance.signOut()`.
2. Show "Password reset successfully".
3. Go to the login screen. **No SteelForce token is returned**, so the user signs in with the new password.

What the server does on success: it sets the password, clears any lockout, and **revokes every session on every device**. Access tokens that were already issued keep working until they expire, which takes at most 15 minutes.

---

## 3. Errors

Errors follow RFC 9457 (`application/problem+json`). **Branch on `status` + `errorCode`**, never on `detail` (it's English text for developers).

```json
{
  "type": "https://docs.isigroup.com.kh/errors/Auth.PhoneNotRegistered",
  "title": "The requested resource was not found.",
  "status": 404,
  "detail": "This phone number is not registered to an account. Please contact your administrator.",
  "errorCode": "Auth.PhoneNotRegistered",
  "correlationId": "…"
}
```

### Step ① `verify-firebase-phone`

| Status | `errorCode` | Cause | What the app does |
|---|---|---|---|
| 400 | `General.Validation` | `firebaseIdToken` empty or too long | Bug in the app. Log it |
| 401 | `Auth.FirebaseTokenInvalid` | Token forged, expired, malformed, or from another Firebase project | Call `getIdToken(true)` and retry **once**. If it fails again, restart phone verification |
| 400 | `Auth.FirebaseTokenNotPhone` | Token is not from SMS phone sign-in (e.g. Google sign-in) | Restart phone verification |
| 400 | `Auth.PhoneVerificationStale` | The SMS code was entered **more than 10 minutes ago** | Send a new code (`verifyPhoneNumber` again) |
| 404 | `Auth.PhoneNotRegistered` | No SteelForce account has this phone number | "This phone number isn't registered. Contact your administrator." |
| 403 | `Auth.AccountInactive` | Account is deactivated | "Your account is deactivated. Contact your administrator." |
| 429 | `General.TooManyRequests` | Rate limit (see §5) | Wait for the `Retry-After` header (seconds) |
| 502 | `Auth.PhoneVerificationUnavailable` | Firebase isn't configured on the server, or Google's keys can't be reached | "Try again later." |

### Step ② `reset-password`

| Status | `errorCode` | Cause | What the app does |
|---|---|---|---|
| 400 | `General.Validation` | Password under 8 or over 128 characters, or `verificationId` missing | Show the field error |
| 400 | `Auth.PasswordResetFailed` | Password breaks the policy (§4). `detail` has the reason | Show the policy message. **The `verificationId` has already been used**, so restart from step ① |
| 404 | `Auth.VerificationNotFound` | `verificationId` unknown, expired (over 5 min), or already used | Restart from phone verification |
| 404 | `Auth.UserNotFound` | Account deleted while resetting | "Contact your administrator." |
| 429 | `General.TooManyRequests` | Rate limit | Wait for `Retry-After` |

> **Important:** the `verificationId` is used up *before* the password is checked against the policy. Because of this, **check the password on the device first** (§4), so a policy failure doesn't send the user back through SMS.

---

## 4. Password rules (check these in the app before step ②)

Production policy:

- at least **12** characters (and at most 128)
- at least one **uppercase** letter, one **lowercase** letter, one **digit** and one **symbol**
- at least **4 different** characters

The development server uses a looser policy (7+ characters) so test accounts work. Build the app's check for the production rules.

---

## 5. Rate limits

Both endpoints share the `sensitive` limit: **10 requests per 5 minutes per IP address**. These requests don't count toward it, because Firebase handles them:

- sending the SMS
- resending it
- checking the code

When over the limit, the server returns `429` with a `Retry-After` header.

Firebase applies its own SMS limits per phone number and per device. Handle `too-many-requests` from `verifyPhoneNumber`.

---

## 6. Phone numbers

- Pass Firebase the number in **E.164**, for example `+85512345678`. Convert local input (`012 345 678`) by dropping the leading `0` and adding `+855`.
- The server matches the token's number to an account by its **last 9 digits**, ignoring formatting. An account saved as `012345678` matches `+85512345678`.
- If two accounts share a phone number, the server picks the first match. Ask an admin to fix duplicate numbers.

---

## 7. Flutter reference

Packages: `firebase_core`, `firebase_auth`. Add `google-services.json` and `GoogleService-Info.plist` for project `steelforce-94963` to the app.

```dart
final auth = FirebaseAuth.instance;

// 1. Send the SMS
await auth.verifyPhoneNumber(
  phoneNumber: '+85512345678',
  timeout: const Duration(seconds: 60),
  verificationCompleted: (cred) async => _onCredential(cred),   // Android auto-retrieval
  verificationFailed: (e) => _showError(e.code),                // e.g. invalid-phone-number, too-many-requests
  codeSent: (verificationId, resendToken) {
    _fbVerificationId = verificationId;
    _resendToken = resendToken;                                  // pass as forceResendingToken to resend
  },
  codeAutoRetrievalTimeout: (_) {},
);

// 2. The user types the code
Future<void> submitCode(String smsCode) => _onCredential(
  PhoneAuthProvider.credential(verificationId: _fbVerificationId, smsCode: smsCode),
);

Future<void> _onCredential(PhoneAuthCredential cred) async {
  final userCred = await auth.signInWithCredential(cred);       // invalid-verification-code -> wrong code
  final idToken = await userCred.user!.getIdToken(true);

  // 3. Exchange for a SteelForce verificationId
  final res = await dio.post('/api/v1/mobile/auth/verify-firebase-phone',
      data: {'firebaseIdToken': idToken});
  _resetVerificationId = res.data['data']['verificationId'] as String;
  _goToNewPasswordScreen();                                      // 5-minute window starts now
}

// 4. Set the new password
Future<void> resetPassword(String newPassword) async {
  await dio.post('/api/v1/mobile/auth/reset-password', data: {
    'verificationId': _resetVerificationId,
    'newPassword': newPassword,
  });                                                            // 204
  _resetVerificationId = null;
  await auth.signOut();                                          // never keep the Firebase session
  _goToLogin(message: 'Password reset successfully.');
}
```

Rules:

- Call step ① **right after** `signInWithCredential`. Don't reuse a Firebase session from earlier, because the server rejects SMS codes older than 10 minutes.
- **Always `signOut()` from Firebase** when the flow ends, whether it succeeded, failed or was cancelled.
- Never log the ID token or the `verificationId`.
- Don't put any Firebase **service-account / Admin SDK** file in the app. The app only needs `google-services.json` and `GoogleService-Info.plist`.

---

## 8. Firebase Console setup (one time)

| Item | Where |
|---|---|
| Enable the **Phone** sign-in provider | Authentication → Sign-in method |
| Register the Android app and add its **SHA-1 and SHA-256** (debug + release + Play signing key) | Project settings → Your apps |
| Register the iOS app, upload the **APNs auth key**, add the reversed client ID URL scheme | Project settings → Cloud Messaging / Xcode |
| Enable **Play Integrity** (Android) / App Check | App Check |
| Add test numbers with fixed codes for QA (no real SMS) | Authentication → Sign-in method → Phone → *Phone numbers for testing* |
| Allow **Cambodia (+855)** for SMS | Authentication → Settings → SMS region policy |

---

## 9. QA checklist

- [ ] Registered number → SMS → new password → 204 → can log in with the new password and **not** with the old one
- [ ] Another device that was signed in gets logged out within 15 minutes (its refresh fails)
- [ ] Unregistered number → `404 Auth.PhoneNotRegistered`
- [ ] Deactivated user → `403 Auth.AccountInactive`
- [ ] Reusing the same `verificationId` → `404 Auth.VerificationNotFound`
- [ ] Waiting more than 5 minutes on the password screen → `404 Auth.VerificationNotFound`
- [ ] Entering the SMS code, waiting more than 10 minutes, then calling step ① → `400 Auth.PhoneVerificationStale`
- [ ] Weak password is blocked on the device before any call is made
- [ ] An 11th request within 5 minutes → `429` with `Retry-After`
