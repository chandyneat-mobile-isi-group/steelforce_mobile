# Firebase SMS OTP — device test guide

> **Scope:** does Firebase send a 6-digit code by SMS to the number entered in
> the app, and does Firebase accept that code? Nothing else. No backend call is
> made and no password changes.
>
> Full reset design: [mobile-integration.md](mobile-integration.md).
> Backend contract (later): [api.md](api.md) §5a.
> Firebase's own Android reference: [Firebase phone auth for Android](https://firebase.google.com/docs/auth/android/phone-auth).

---

## 1. How the test runs

The app's *Forgot password* screen, in **check-only mode**:

```
Forgot password → enter +855… → Firebase verifyPhoneNumber()
  → (iOS: reCAPTCHA page, returns to the app)
  → codeSent → SMS arrives → enter the code
  → Firebase confirms it → "DEBUG: Firebase verified this phone" → back to login
```

Check-only mode is `AppConfig.firebasePhoneCheckOnly`. It is compiled out of
release builds (`kReleaseMode`).

**Start it** — a plain *Run* does **not** turn it on; the reset then goes to the
backend SMS (`forgot-password/request` in the log) and Firebase is never called.

| From | How |
|---|---|
| VS Code | Run and Debug → **SteelForce — Firebase OTP test** (`.vscode/launch.json`) |
| Terminal | `flutter run --dart-define=FIREBASE_PHONE_CHECK_ONLY=true` |

Stop the app fully before switching — hot reload does not pick up a
`--dart-define` or a native iOS change.

---

## 2. Before the first run

### 2.1 Firebase console

> ⚠️ **The two platforms currently use different Firebase projects:**
> Android → `steelforce-94963` (`android/app/google-services.json`),
> iOS → `isig-dev-steelforce` (`ios/Runner/GoogleService-Info.plist`).
> Do every check below **in the project of the platform you are testing**.
> The `auth.phone_firebase_ready project=…` log line names the one in use.

| ✓ | Check | Where | Why it matters |
|---|---|---|---|
| ☐ | **Phone** provider enabled | Authentication → Sign-in method → Phone | Otherwise `operation-not-allowed` |
| ☐ | **Cambodia (+855) allowed** in the SMS region policy | Authentication → Settings → SMS region policy | **New projects allow no regions by default.** Firebase then refuses to send to +855 |
| ☐ | Billing enabled for SMS | Usage and billing | Without it real SMS may not be sent; only fictional test numbers work. Confirm the project's plan |
| ☐ | The number you test with is **not** under *Phone numbers for testing* | Sign-in method → Phone → Phone numbers for testing | A test number never receives an SMS — you type the fixed code instead |
| ☐ | Browser API key not restricted away from `<project-id>.firebaseapp.com` | Google Cloud → APIs & Services → Credentials | The reCAPTCHA fallback needs it |

### 2.2 Android

| ✓ | Check |
|---|---|
| ☐ | `applicationId` is `com.isisteel.steelforce` (`android/app/build.gradle.kts`) and matches `android/app/google-services.json` |
| ☐ | **SHA-1 and SHA-256** of the signing key are added to the Android app in the Firebase console, and `google-services.json` was downloaded **after** adding them. Without them: `app-not-authorized` / `missing-client-identifier` |
| ☐ | The device has Google Play services (Play Integrity). Without it Firebase falls back to reCAPTCHA in a browser tab — expected on most emulators |

Read the debug key's fingerprints (each developer machine has its own):

```bash
"/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool" \
  -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android \
  | grep -E "SHA1:|SHA256:"
```

### 2.3 iOS

| ✓ | Check |
|---|---|
| ☐ | `ios/Runner/GoogleService-Info.plist` is the `isig-dev-steelforce` one (Xcode reads only `Runner/`) |
| ☐ | Bundle ID `com.isisteel.steelforce` in Xcode, with a signing profile for team `78J4ZZY473` |
| ☐ | `Info.plist` has the URL scheme `app-1-696334570059-ios-237039f985603918b0f3ce` — Firebase returns from reCAPTCHA through it |
| ☐ | `SceneDelegate.swift` keeps that return URL away from Flutter. Without it the app shows *"Not found — No route: /link?deep_link_id=…"* |
| ☐ | *Optional:* APNs key uploaded (Firebase → Project settings → Cloud Messaging) and the Push Notifications capability on. Then iOS verifies silently; without it a reCAPTCHA page opens first, which is fine for this test |

The **iOS Simulator cannot receive SMS**. Use a real iPhone, or a fictional test
number on the Simulator.

---

## 3. Run the test

Use a **real number you hold**, in full international form (`+855…`), on the
physical phone that owns that SIM.

| # | Step | Expected on screen | Expected in the console |
|---|---|---|---|
| 1 | Start the app with the Firebase OTP test config | — | `bootstrap.started … resetFlow=firebase-check-only` |
| 2 | Login → **Forgot password** → enter the number → send | iOS: a reCAPTCHA page, then back to the app | `auth.phone_send_started` → `auth.phone_firebase_ready project=<project-id>` |
| 3 | — | Code screen | iOS: `[ISI] auth.phone_recaptcha_returned handledBy=Firebase`* → `auth.phone_code_sent` → `auth.phone_code_requested outcome=code_sent` |
| 4 | Wait for the SMS (usually < 1 min) | SMS from Firebase with a 6-digit code | — |
| 5 | Type the code from the SMS | Snackbar *"DEBUG: Firebase verified this phone…"*, back to login | `auth.phone_confirm_started` → `auth.phone_id_token_obtained` → `auth.phone_check_only_verified backendExchange=skipped` |

\* Native line: on a physical iPhone it may appear only in Xcode → Devices and
Simulators → Open Console.

**`auth.phone_code_sent` means Firebase accepted the request.** From that point
a missing SMS is a delivery problem (§4.2), not an app problem.

### Where the SMS lands

- **iPhone:** an SMS from an unknown sender can go to **Messages → Filters →
  Unknown Senders**, which shows **no notification**. iOS may still offer the
  code above the keyboard — tapping it fills the code without the message ever
  being opened. Check that folder before concluding no SMS was sent.
- **Android:** the default SMS app. Android may also read the code itself
  (`auth.phone_auto_verified afterCodeSent=true` in the log).

---

## 4. When it fails

### 4.1 Read the log line first

| Log line | Cause | Fix |
|---|---|---|
| `resetFlow=backend-sms`, or a `forgot-password/request` call | App started without the flag | §1 — use the Firebase OTP test config |
| `auth.phone_send_failed code=operation-not-allowed` | Phone provider off, or +855 blocked by the region policy | §2.1 rows 1–2 |
| `auth.phone_send_failed code=app-not-authorized` / `missing-client-identifier` | Android SHA fingerprints missing, or old `google-services.json` | §2.2 |
| `auth.phone_send_failed code=quota-exceeded` / `billing-not-enabled` | SMS quota or billing | §2.1 row 3 |
| `auth.phone_send_failed code=too-many-requests` | Firebase is throttling this device or number | Wait, or use a fictional test number |
| `auth.phone_send_failed code=invalid-phone-number` | Not E.164 | Enter `+855` and the number without the leading 0 |
| `auth.phone_send_timeout` | No answer from Firebase in 90 s | iOS: was `auth.phone_recaptcha_returned` logged? If not, the reCAPTCHA return did not reach Firebase (§2.3) |
| `auth.phone_firebase_unavailable` | Firebase could not start | Config file does not match the app ID / bundle ID |
| `auth.phone_confirm_failed code=invalid-verification-code` | Wrong code | Re-type; only the newest code works |
| `auth.phone_confirm_failed code=session-expired` | Code too old | Send again |
| *"Not found — No route: /link?deep_link_id=…"* on iOS | reCAPTCHA return URL reached Flutter | §2.3 — `SceneDelegate.swift`; stop and rebuild the app |

`message=` on a failure line is Firebase's own explanation — quote it when
reporting.

### 4.2 `code_sent` logged, but no SMS

1. iPhone: Messages → Filters → **Unknown Senders**.
2. The number is not a Firebase **test number** (§2.1 row 4).
3. Wait two minutes — delivery to Cambodian carriers can lag.
4. The SIM can receive SMS from short codes / international senders (some
   prepaid plans block them).
5. Try a second number on another carrier to separate a carrier problem from a
   project problem.

### 4.3 Code accepted, but no SMS was ever seen

Firebase accepts a real number's code only if it matches the SMS it sent. So
either the number is a test number, or the SMS was delivered and filled in by
keyboard autofill without being opened (§3, *Where the SMS lands*).

---

## 5. Record the result

| Date | Tester | Device / OS | Platform path | Number (last 3 digits) | `code_sent` | SMS received (secs) | Code accepted | Notes / log line |
|---|---|---|---|---|---|---|---|---|
| | | | Play Integrity / reCAPTCHA / APNs | | ☐ | ☐ | ☐ | |

Do not paste full phone numbers, codes, or reCAPTCHA URLs into tickets or
chat — the app's logs already mask them for that reason.

---

## 6. Done when

- [ ] Android, real number: `code_sent` logged, SMS received, code accepted.
- [ ] iOS, real number: same, with no *"Not found"* screen.
- [ ] A wrong code shows *"That code isn't right"* and logs `invalid-verification-code`.
- [ ] Results recorded in §5 for both platforms.

Then the next step is the backend exchange (`--dart-define=PASSWORD_RESET_VIA_FIREBASE=true`,
api.md §5a).
