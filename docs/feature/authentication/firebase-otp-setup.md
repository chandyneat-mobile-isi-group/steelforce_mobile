# Setup guide: Firebase SMS code and password reset

**For:** mobile developers setting up or debugging the phone-verified password
flows on their machine.
**Checked against:** staging OpenAPI (`www.pnc-spts-stg-api.me`), 2026-10-22.

Follow the steps in order. Each one says what to do, where, and how to check it
worked. Background and the full API contract live in
[mobile-integration.md](mobile-integration.md); this page is the checklist.

---

## 0. What you are setting up

The app has two flows. Both use a Firebase SMS code to prove the rep holds the
phone. Neither uses the Firebase sign-in as the app session: the app session is
always the backend's own tokens.

| Flow | Where in the app | Signed in? | Endpoints, in order |
|---|---|---|---|
| **Forgot password** | Login → *Forgot password* | No | `POST /auth/otp/request` `{phoneNumber}` → Firebase SMS → `POST /auth/forgot-password/phone/verify` → `POST /auth/forgot-password/reset` |
| **Change password** | Profile → *Change password* | Yes (Bearer token) | `POST /auth/otp/request` `{phoneNumber}` (the account's own number) → Firebase SMS → `POST /auth/password/phone/verify` → `POST /auth/password` |

All paths start with `/api/v1`. **Do not mix the two columns**:
`/auth/password/phone/verify` needs a signed-in user and answers 401 on the
forgot-password screen.

Both flows:

```
App ──start──▶ API            API opens a verification, returns the E.164 number
App ──verifyPhoneNumber──▶ Firebase ──"may I send?"──▶ API (SMS gate)
Rep types code ──▶ Firebase sign-in ──▶ fresh Firebase ID token
App ──verify {firebaseIdToken}──▶ API   returns a one-time token
App ──new password + that token──▶ API
```

Two separate protections, often confused:

| | Protects | Required? |
|---|---|---|
| **Firebase Phone Auth** | Sends and checks the SMS code | Yes |
| **Firebase App Check** | Proves the request comes from our real app. Enforced on Firebase Authentication, so phone sign-in fails without it | Yes |

---

## 1. Before you start

You need:

- Access to the Firebase project **`steelforce-94963`** (ask the project owner).
- Flutter matching `pubspec.yaml`, Xcode for iOS, Android Studio / JDK for Android.
- A **real SIM card** with a Cambodian (`+855`) number for an account on the
  target backend. Firebase test phone numbers skip the backend's SMS gate, so the
  backend refuses their proof at the verify step.

App identifiers (both platforms): **`com.isisteel.steelforce`**.

Packages already in `pubspec.yaml`: `firebase_core`, `firebase_auth`,
`firebase_app_check`.

---

## 2. Firebase config files

1. Firebase console → Project settings → *Your apps*.
2. Download for the app with ID `com.isisteel.steelforce`:
   - Android: `google-services.json` → `android/app/google-services.json`
   - iOS: `GoogleService-Info.plist` → `ios/Runner/GoogleService-Info.plist`
     (add it to the Runner target in Xcode).
3. **Do not commit them.** Both are in `.gitignore`.

**Check:** run the app and look for
`auth.phone_firebase_ready project=steelforce-94963` in the console when you
request a code.

---

## 3. Enable phone sign-in

Firebase console → Authentication → *Sign-in method*:

1. Enable **Phone**.
2. Authentication → Settings → *SMS region policy*: allow **Cambodia (KH)**. The
   backend allows only `KH` numbers anyway.
3. Leave *Phone numbers for testing* empty for end-to-end tests (see step 1).

---

## 4. Android setup

### 4.1 Register the signing fingerprints

Phone auth and Play Integrity need the SHA-1 **and** SHA-256 of every key that
signs the app.

```bash
cd android
./gradlew signingReport        # debug keystore: look for "Variant: debug"
```

Add these in Firebase console → Project settings → Android app → *Add
fingerprint*:

| Key | Where to get it |
|---|---|
| Debug keystore (each developer's machine) | `./gradlew signingReport` |
| Release upload key | `keytool -list -v -keystore <release.jks> -alias <alias>` |
| Play App Signing key | Play Console → Setup → App integrity |

Then download `google-services.json` again (step 2).

### 4.2 Play Integrity

Google Cloud console (same project) → APIs → enable **Play Integrity API**.

**Check:** a code request on a real device should log
`event=code_sent`. If it logs `app-not-authorized` or
`missing-client-identifier`, the fingerprint is missing (see §9).

---

## 5. iOS setup

1. **APNs key:** Apple Developer → Keys → create an APNs key, then Firebase console
   → Project settings → Cloud Messaging → *Apple app configuration* → upload it.
   Firebase verifies the app with a silent push.
2. **Xcode → Runner → Signing & Capabilities:** add *Push Notifications* and
   *Background Modes → Remote notifications*.
3. **URL scheme for the reCAPTCHA fallback.** When silent push is not available
   (simulator, push denied), Firebase opens a reCAPTCHA page and returns to the
   app through a URL scheme. It must be the **Encoded App ID** from Firebase
   console → Project settings → iOS app (it looks like
   `app-1-696334570059-ios-…`). It is in `ios/Runner/Info.plist` under
   `CFBundleURLTypes` → `firebase-phone-auth`. **Update it whenever the iOS app is
   re-registered in Firebase.**
4. `ios/Runner/SceneDelegate.swift` already hands that return URL to Firebase
   before Flutter's deep links see it. Don't remove it.

**Check:** on a real iPhone the code request logs `event=code_sent` within a few
seconds. A hang that ends with `auth.phone_send_timeout` means the reCAPTCHA
return never reached Firebase: check the URL scheme (step 3).

---

## 6. App Check

App Check is enforced on Firebase Authentication. Without a valid App Check
token, phone sign-in fails.

| Build | Android provider | iOS provider |
|---|---|---|
| Debug | Debug provider | Debug provider |
| Release | reCAPTCHA Enterprise (site key in `lib/core/firebase/firebase_app_check.dart`) | App Attest, falling back to DeviceCheck |

### 6.1 Debug builds: register a debug token

1. Generate a UUID once: `uuidgen`.
2. Firebase console → App Check → Apps → Android app → ⋮ → *Manage debug tokens*
   → add the UUID. Do the same for the iOS app.
3. Pass it on every debug run, **never commit it**:

   ```bash
   flutter run --dart-define=APP_CHECK_DEBUG_TOKEN=<your-uuid>
   ```

Without it the SDK makes a random token per install, which you would have to
find in the native log and register by hand.

### 6.2 Release builds

- Android: the reCAPTCHA Enterprise key in `firebase_app_check.dart` must be
  registered for this app under App Check → Android app → *reCAPTCHA Enterprise*.
- iOS: App Check → iOS app → register **App Attest** and **DeviceCheck** (DeviceCheck
  needs a DeviceCheck key from Apple Developer).

**Check:** the forgot-password screen logs `app check passed after …ms` when you
tap *Start security check*.

---

## 7. Backend you point at

Check before blaming the app:

| Requirement | How to tell |
|---|---|
| API runs with `PASSWORD_RESET_PHONE_CHANNEL=Firebase` | Otherwise both `start` endpoints answer `400 AUTH_PHONE_CHANNEL_DISABLED` |
| The SMS gate (Cloud Function asking the API before each SMS) is deployed | Otherwise the backend refuses every proof at verify |
| The endpoints in §0 exist | Open `<host>/swagger/v1/swagger.json` and search for `phone/start` |

On 2026-10-22, **staging** (`www.pnc-spts-stg-api.me`, used by debug builds)
serves all of them. **`api-dev.steelforce.app`** (the app's production setting)
serves neither `phone/start` endpoint nor `phone/verify`.

The base URL comes from `.env` (`API_BASE_URL_DEV` / `API_BASE_URL_PRO`), or for
one run: `--dart-define=API_BASE_URL=https://…`.

---

## 8. Run and test

Typical debug run:

```bash
flutter run --dart-define=APP_CHECK_DEBUG_TOKEN=<your-uuid>
```

> **Staging needs `PASSWORD_RESET_PHONE_CHANNEL=Firebase`.** Without it, both
> flows answer `400 AUTH_PHONE_CHANNEL_DISABLED` at `start` and `verify`, before the
> backend reads anything (2026-10-22).

### 8.1 Build flags

All are `--dart-define`s. The debug-only ones are forced off in release builds.

| Flag | Default | Effect |
|---|---|---|
| `APP_CHECK_DEBUG_TOKEN` | unset | Fixed App Check debug token (§6.1) |
| `PASSWORD_RESET_VIA_FIREBASE` | `true` | `false` turns the forgot-password SMS off |
| `FIREBASE_PHONE_CHECK_ONLY` | `false` | Debug only. Stops after Firebase accepts the code; no backend call, no password change |

### 8.2 Test checklist

Forgot password (signed out):

- [ ] Known number: SMS arrives, code accepted, new password works at sign-in.
- [ ] Unknown number: neutral "if an account exists…" text, no SMS, nothing reveals
      whether the number has an account.
- [ ] Wrong code: "That code isn't right", boxes clear, retry works.
- [ ] Resend after the countdown: a new SMS arrives.
- [ ] Weak password: the server's message shows and a better password succeeds
      without a new code.

Change password (Profile, signed in):

- [ ] The code screen shows the masked number (`+855 •• ••• 678`).
- [ ] Success: "Password Changed"; other devices are signed out, this one stays in.
- [ ] Waiting more than 5 minutes on the password step asks for a new code.
- [ ] An account with no phone number: "Ask an administrator to add one."

Healthy forgot-password log, in order:

```
[password-reset.ui] app check passed after …ms
[password-reset] --> POST /api/v1/auth/forgot-password/phone/start
[password-reset] ... FirebaseAuth.verifyPhoneNumber … event=code_sent
[password-reset] ... FirebaseAuth.signInWithCredential … event=code_accepted_and_id_token_obtained
[password-reset] --> POST /api/v1/auth/forgot-password/phone/verify
[password-reset] --> POST /api/v1/auth/forgot-password/reset
```

The change-password flow logs under `[password-change.flow]` and calls the
`/auth/password/…` endpoints instead.

---

## 9. Troubleshooting

| Symptom in the log | Cause | Fix |
|---|---|---|
| `401` with `AUTH_UNAUTHENTICATED` on `mobile/auth/verify-firebase-phone` | An old build with the retired endpoints | Pull the current branch; the endpoints are in §0 |
| `401 AUTH_PHONE_PROOF_INVALID` at verify | The code is over 5 minutes old; a Firebase test number; or the token was already used | Request a new code, use a real SIM |
| `auth.phone_send_failed code=app-not-authorized` or `missing-client-identifier` | Missing SHA fingerprint, or an old `google-services.json` | §4.1, then download the config again |
| `code=invalid-app-credential` / App Check error | Debug token not registered, or not passed | §6.1 |
| iOS hangs, then `auth.phone_send_timeout` | The reCAPTCHA return did not reach Firebase | Check the Encoded App ID URL scheme (§5 step 3) and `SceneDelegate.swift` |
| `code=too-many-requests` / `quota-exceeded` | Firebase throttling this device or project | Wait, or use another device |
| `400 AUTH_PHONE_CHANNEL_DISABLED` | Backend not on the Firebase channel | Backend config (§7) |
| `400 AUTH_PHONE_NUMBER_REQUIRED` | The signed-in account has no phone number | An administrator adds the number |
| `429 AUTH_RESET_REQUEST_LIMIT_EXCEEDED` | 60 s cooldown, 5 starts per hour, 10 per day per number | Wait for the countdown |
| `[isi.error] api.error … status=404` on a `phone/…` path | The target backend doesn't serve it yet | Point at staging (§7) |

Each backend error logs a `correlationId`. Give it to the backend team; it finds
the request in their logs.

---

## 10. Rules that keep this safe

- Never log or persist a phone number, SMS code, Firebase ID token, reset token
  or phone proof token. The request trace logs field **names** only.
- Pass the number from `start` to Firebase **unchanged**. In the change-password
  flow the number comes from the account, never from the device.
- Sign out of Firebase right after getting the ID token. The verifier already
  does this.
- Don't use Firebase's own resend (`forceResendingToken`) for the change-password
  flow: the backend allows one SMS per verification, so a resend is a new `start`.
- Never retry the verify or password calls automatically. Their tokens are single
  use, and a dropped connection may already have spent them.
- Keep the debug flags out of release builds; they are marked
  `TODO(release-gate)` in `lib/core/config/app_config.dart`.

---

## 11. Where the code is

| Concern | File |
|---|---|
| Endpoints | `lib/core/network/api/api_endpoints.dart` |
| Build flags | `lib/core/config/app_config.dart` |
| App Check | `lib/core/firebase/firebase_app_check.dart` |
| Firebase SMS and ID token | `lib/features/authentication/data/datasources/phone_ownership_verifier.dart` |
| Forgot password: API calls | `…/data/datasources/phone_reset_remote_data_source.dart`, `auth_remote_data_source.dart` (`resetPassword`) |
| Forgot password: flow | `…/data/repositories/phone_ownership_reset_repository_impl.dart`, routes in `lib/routes/app_page.dart` |
| Change password: API calls | `…/data/datasources/phone_password_change_remote_data_source.dart` |
| Change password: flow | `…/presentation/bloc/phone_password_change_cubit.dart`, `…/presentation/screens/phone_password_change_flow.dart` |
| Error texts | `…/presentation/phone_verification_messages.dart`, `assets/lang/en.json` + `km.json` |
| Tests | `test/features/authentication/firebase_password_reset_test.dart`, `phone_password_change_test.dart`, `phone_password_change_flow_test.dart` |

`…` = `lib/features/authentication`.

Related: [mobile-integration.md](mobile-integration.md) (API contract) ·
[Firebase phone auth for Android](https://firebase.google.com/docs/auth/android/phone-auth)
(Firebase's Android reference).
