# SteelForce — Android release for Google Play

> **Purpose:** the release record and runbook for uploading SteelForce to Google
> Play. It covers this specific build and the Play Console steps that remain.
> **Verified:** 2026-10-29, branch `feat/customers` @ `5199c29` **plus
> uncommitted work in the tree** (see §A).
> **No secret appears in this document.** Variable and file *names* only.
>
> General signing, CI and Firebase App Distribution detail lives in
> [release/android-release.md](release/android-release.md); configuration keys
> live in [release/environment.md](release/environment.md). This document does
> not repeat them.

---

## A. Release information

| Item | Value | How it was verified |
|---|---|---|
| Application name | **SteelForce** | `android/app/src/main/res/values/strings.xml` |
| Package / applicationId | **`com.isisteel.steelforce`** | Merged release manifest; matches `package_name` in `google-services.json` |
| Kotlin namespace | `com.isigroup.steelforce` (internal only, not the install identity) | `android/app/build.gradle.kts` |
| Version name / code | **1.0.0 / 1** | `pubspec.yaml` `version: 1.0.0+1`; merged release manifest |
| minSdk / targetSdk / compileSdk | **24 / 36 / 36** | Flutter 3.44.9 defaults; merged release manifest |
| Build date | 2026-10-29 | AAB timestamp |
| Flutter / Dart | 3.44.9 (stable) / 3.12.2 | `flutter --version` |
| Android Gradle Plugin / Gradle / Kotlin | 9.0.1 / 9.1.0 / 2.3.20 | `android/settings.gradle.kts`, wrapper |
| Google services plugin | 4.4.4 | `android/settings.gradle.kts` |
| JDK used to build | OpenJDK 25.0.2 (Android Studio's bundled JBR); bytecode target Java 17 | `flutter doctor -v`, `build.gradle.kts` |
| Android SDK build-tools / NDK | 36.0.0 / 28.2.13676358 | `flutter doctor -v`, Flutter defaults |
| Build type | Release: R8 minify + resource shrink, Dart `--obfuscate`, symbols split out | `tool/build_release.sh` |
| CPU architectures | arm64-v8a, armeabi-v7a (no x86) | Listed from the bundle |
| Signing status | **Signed with the release/upload key**, `jar verified`. Certificate `CN=mobiledev, OU=isi-steel, O=isi-steel, C=KH`, RSA 2048, valid 2026-10-05 → 2054-02-20 | `jarsigner -verify`, `keytool -printcert` |
| Upload certificate SHA-1 | `73:03:3B:F0:D1:0C:73:E0:10:DB:5D:A1:38:F1:1E:EF:83:FF:45:82` | `keytool -printcert` (a fingerprint is public, not a secret) |
| Upload certificate SHA-256 | `2B:88:1E:14:79:A0:2A:CB:40:38:1D:55:42:D8:18:C8:AA:83:A7:FF:12:E7:62:CB:FB:69:DB:62:B3:AE:B9:00` | `keytool -printcert` |
| Firebase project | **steelforce**, the one Firebase project for this app (project ID `steelforce-94963`, Android app `1:696334570059:android:f70d69129448bce4b0f3ce`) | `android/app/google-services.json` |
| API environment | **production**: built with `--dart-define=APP_ENV=production`, which is also the release default, so every request uses `API_BASE_URL_PRO` from `.env`. All network code reads the host through `AppConfig.apiBaseUrl`; no other backend host is hard-coded | `lib/core/config/app_config.dart`, `lib/core/network/app_network.dart` |
| AAB | **`build/app/outputs/bundle/release/app-release.aab`** (71.3 MB) | Built 2026-10-29 |
| Debug symbols | `build/symbols/appbundle/1.0.0+1/` | Output of `tool/build_release.sh` |
| Previous Play uploads | **TODO, confirm.** The repo has no release tags and no record of a Play upload | `git tag` is empty |

> ⚠️ **This build includes uncommitted work** on `feat/customers` (the
> notifications inbox on `/me/notifications`, offline prefetch, Visits changes).
> Before a build goes to Play, commit it, tag the commit (e.g. `v1.0.0+1`), and
> rebuild from that clean tree. Otherwise the shipped binary has no exact source
> to point back to.

---

## B. Prerequisites

| Requirement | Detail |
|---|---|
| Flutter SDK | **3.44.9 stable** (the version this was built and tested with) |
| Android SDK | Platform 36, build-tools 36.0.0, NDK 28.2.13676358 (Gradle fetches the NDK if it is missing). Accept licences once with `flutter doctor --android-licenses`; this machine still reports some as unaccepted |
| JDK | 17 or newer. Android Studio's bundled JBR works; Flutter finds it automatically. There is **no system `java`** on this machine, so plain `./gradlew` from a shell needs `JAVA_HOME` pointed at the JBR |
| `.env` (git-ignored) | Envied input. Release builds need `API_BASE_URL_PRO` (**https only**: a release build refuses to start on `http://`) and `DB_SALT` (fixed for the life of the environment; changing it makes every device's database unreadable). Keys: [release/environment.md](release/environment.md). Regenerate after any edit: `dart run build_runner build --delete-conflicting-outputs` |
| `android/app/google-services.json` (git-ignored) | From the Firebase project **steelforce** (`steelforce-94963`), with `package_name` = `com.isisteel.steelforce` |
| Google Maps key | `GOOGLE_MAPS_ANDROID_KEY` from the environment or `.env`. It is injected as a manifest placeholder; an empty key builds fine but maps don't load |
| Signing | `android/key.properties` (git-ignored) pointing at the upload keystore, **or** the CI variables `ANDROID_KEYSTORE_PATH`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`. Without them Gradle **refuses** to build a release; it never falls back to the debug key |

---

## C. Build commands

From the project root. There are **no flavors**. A release build already defaults to
the production API; `APP_ENV=production` is passed anyway so the intent is
visible in the command. Never pass `API_BASE_URL` to a Play build: it overrides
the production host.

```bash
flutter doctor -v
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # after any .env or Drift change
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
tool/build_release.sh appbundle --dart-define=APP_ENV=production    # first upload: 1.0.0+1
# later uploads: bump `version:` in pubspec.yaml, or add --build-number=2
```

`tool/build_release.sh appbundle` runs `flutter build appbundle --release
--obfuscate --split-debug-info=build/symbols/appbundle/<version>
--target-platform=android-arm,android-arm64`. Use it rather than a bare
`flutter build appbundle`, which would skip obfuscation and the symbol split.

Verify the output:

```bash
AAB=build/app/outputs/bundle/release/app-release.aab
JBR="/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin"
"$JBR/jarsigner" -verify "$AAB"                 # expect "jar verified."
"$JBR/keytool" -printcert -jarfile "$AAB"       # must NOT say CN=Android Debug
grep -oE 'package="[^"]*"|versionCode="[^"]*"|versionName="[^"]*"|targetSdkVersion="[^"]*"' \
  build/app/intermediates/merged_manifests/release/processReleaseManifest/AndroidManifest.xml
```

`jarsigner` also warns *"certificate chain is invalid … PKIX path building
failed"*. That is expected for a self-signed upload key and is not an error.

**Expected build noise, not errors:**
- the Kotlin Gradle Plugin deprecation warnings (tracked in `android/gradle.properties`);
- *"ELF library contains unobfuscated DWARF"* (the intermediate library; the packaged one is stripped);
- JDK `sun.misc.Unsafe` / `System::load` warnings.

---

## D. Google Play Console checklist

**Required** must be done for every release. **Conditional** applies only in
the case named. Nothing below has been done yet; it all needs Play Console access.

### Required

- [ ] Confirm access to the right Play developer account (ISI Group / ISI Steel) and the app entry for **`com.isisteel.steelforce`**. The package name is permanent after the first upload.
- [ ] Confirm the version code is higher than any earlier upload to **any** track. This build is versionCode **1**, which is valid only if Play has never received this package. Otherwise rebuild with `--build-number=<higher>`.
- [ ] Enrol in **Play App Signing** (the default for new apps) and keep Google-generated app signing. The key in this build then becomes the **upload key**. See §G.
- [ ] After enrolment, copy the **app signing key** SHA-1 and SHA-256 from *Test and release → Setup → App signing*, then:
  - add them **and** the upload-key fingerprints from §A to Firebase (*Project settings → Your apps → Android → SHA certificate fingerprints*). Firebase phone verification, used in password reset, fails on installs from Play without them;
  - add the app-signing SHA-1 to the **Google Maps Android API key** restriction in Google Cloud Console, if the key is restricted by package and certificate. Otherwise maps are blank on Play installs.
- [ ] Upload `app-release.aab` to a testing track first (internal testing), not production.
- [ ] Read every Play Console warning and error on the release page before promoting.
- [ ] **App content → Privacy policy:** provide a public URL. **TODO, none is recorded in this repo.**
- [ ] **App content → Data safety.** Declare what the app actually collects:
  - precise and approximate location (check-in, depot GPS);
  - name, phone number and email (rep profile, password reset);
  - photos (check-in and depot photos);
  - audio (speech-to-text);
  - device IDs and the push token (device registration);
  - business and customer records synced to the company backend.

  Data is encrypted in transit (HTTPS enforced in release) and at rest on the device (SQLCipher). Account deletion is set by company policy. **TODO, confirm.**
- [ ] **Content rating** questionnaire (business / utility app).
- [ ] **App access:** the app requires sign-in. Give the reviewer a working **test rep account** and step-by-step sign-in instructions. **TODO, an account must be created** on the production backend with non-sensitive data.
- [ ] **Target audience:** 18+ / not for children.
- [ ] **Ads:** declare *No ads*. No ads SDK is in the dependency list.
- [ ] **Permissions review.** The release manifest requests:
  - location (fine and coarse, foreground only; background location is explicitly removed);
  - camera, microphone, notifications;
  - internet and network state;
  - wake lock, vibrate, boot-completed;
  - `FOREGROUND_SERVICE` and `FOREGROUND_SERVICE_SHORT_SERVICE` (added by WorkManager);
  - Firebase messaging permissions.

  No broad media or storage permission is requested; the gallery uses the system Photo Picker.
- [ ] Release name and release notes (template: [release/release-notes.template.txt](release/release-notes.template.txt)).
- [ ] Submit for review, then roll out.

### Conditional

- [ ] **Foreground service declaration:** if Play Console asks about foreground service types, declare WorkManager's *short service* (background sync). The app starts no location foreground service.
- [ ] **New personal developer account:** if the Play account is a *personal* account created after November 2023, Google requires a closed test with at least 12 testers for 14 continuous days before production access. An organisation account is exempt.
- [ ] **Managed Google Play / private app:** if SteelForce should be visible only to ISI devices, publish it as a private app through the organisation's managed Google Play instead of a public listing.
- [ ] **Government ID, financial or health declarations:** not applicable to this app, unless Play asks.

---

## E. Android testing checklist

Install the build **from the Play internal testing track** on at least one
physical phone (the build has no x86 code, so an x86 emulator cannot install the
release AAB's splits; use an arm64 emulator image or a real phone).

- [ ] Fresh install → launch → the SteelForce name and adaptive icon look right on the home screen.
- [ ] Sign in, sign out, sign in again; a session expiring returns to sign-in.
- [ ] Password reset through Firebase phone verification, on a Play-installed build (this checks the SHA fingerprints from §D).
- [ ] The app talks to the **production** API (check a known production record), and a release build never shows debug snackbars.
- [ ] Push: allow the Android 13+ notification prompt from the in-app explainer; receive a notification in foreground, background and after force-close; tapping one opens the right screen.
- [ ] Push denied: the inbox still syncs, and the in-app banner points to settings.
- [ ] Depots, Visits and check-in work end to end with real GPS. Turning on "mock location" blocks check-in, as it should in release.
- [ ] Location permission denied, and denied permanently: check-in explains and links to settings, with no crash.
- [ ] Camera photo at check-in and depot capture; gallery pick through the Photo Picker; camera permission denied.
- [ ] Speech-to-text, and microphone permission denied.
- [ ] Quotations and orders: hidden in this build (`ORDERS_COMING_SOON` defaults to true). Confirm the Orders tab shows "coming soon".
- [ ] Offline: airplane mode → browse cached data, make a check-in → reconnect → it syncs.
- [ ] Force close and reopen mid-flow; reboot the phone; rotate the screen; Android back button from every top-level tab.
- [ ] Khmer language on a small phone (no clipped text).

---

## F. Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `Release signing is not configured …` | No `android/key.properties` and no `ANDROID_KEYSTORE_PATH`. Add one (§B). This guard is intentional |
| `Release signing is incomplete — missing: …` | A blank value or a wrong `storeFile` path. The message names the field, never the value |
| `No matching client found for package name` | `google-services.json` is from another Firebase app. Download the one for `com.isisteel.steelforce` |
| `processReleaseGoogleServices` fails on a fresh clone | `google-services.json` is git-ignored; copy it in |
| `Unable to locate a Java Runtime` from `./gradlew` | No system JDK. Use `flutter build …`, or `export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"` |
| `Unsupported class file major version` / Gradle JVM errors | The JDK is older than 17. Use the Android Studio JBR |
| `Some Android licenses not accepted` | `flutter doctor --android-licenses` |
| Envied / `env.g.dart` errors | `.env` is missing a key. Compare with `.env.example`, then rerun `build_runner` |
| App closes at launch, only in release | `API_BASE_URL_PRO` is `http://` or carries a path; release enforces an https host only |
| Play: *"Version code 1 has already been used"* | Rebuild with `--build-number=<next>`. Version codes can never be reused, even from a deleted release |
| Play: *"signed with the wrong key"* | The upload key differs from the one registered with Play App Signing. Use the original upload keystore, or request an upload-key reset in Play Console |
| Play: *"must target API level …"* | Raise `targetSdk` by upgrading Flutter; it currently follows `flutter.targetSdkVersion` (36) |
| Play: *"debuggable"* or *"signed in debug mode"* | A debug build or debug key was uploaded. Rebuild with `tool/build_release.sh appbundle` |
| Phone verification fails, only on Play installs | The Play app-signing SHA-256 is missing in Firebase (§D) |
| Maps blank, only on Play installs | The Maps key restriction lacks the app-signing SHA-1 (§D) |

---

## G. Release security

- **Two keys, two jobs.** With Play App Signing, *Google* holds the **app
  signing key** that users' phones trust. We hold only the **upload key**, which
  proves an upload came from us. A lost or leaked upload key can be reset
  through Play Console support; a lost app signing key can't be recovered.
  That is the reason to let Google keep it.
- **The upload key in use today** is `android/keystore/steelforce-release.jks`.
  It is git-ignored (`.gitignore`: `android/keystore/`), but it sits **inside
  the working copy**. Move it outside the repo, store it and its passwords in
  the company password vault, and keep an offline backup. Don't create a new key
  if this one has already signed anything that reached Play or testers; check
  first.
- **Never commit or share:** `android/key.properties`, any `*.jks` / `*.keystore`,
  `.env`, `lib/core/config/env.g.dart`, `google-services.json`, a Firebase or
  Google Cloud service-account JSON, or the `build/symbols/` folder. The symbols
  map every obfuscated name back to the source: archive them privately per
  release, because they are the only way to read a production crash stack
  (`flutter symbolize`).
- **CI:** secrets go in masked, protected CI variables
  ([release/android-release.md](release/android-release.md) §5), never in a
  workflow file.
- **Production configuration** (`API_BASE_URL_PRO`, `DB_SALT`) changes only
  with the release owner's sign-off. Rotating `DB_SALT` is a data-loss event.
- **Play Console access:** give each person their own account with the least
  role they need, and turn on 2-step verification for everyone.

---

## Known release risks found while preparing this build

Not fixed here, because each one is a product decision, not a build change:

1. **Placeholder promotions are reachable in release.** *Promotions*, opened from
   stop information and from depot detail, shows hard-coded sample promotions
   (`promotions_mock_data.dart`, marked `TODO(release-gate)`). Hide the entry
   point or accept that reps see sample data.
2. **Check-in photos are not encrypted at rest** (`visit_tables.dart`,
   `TODO(release-gate)`). The database is encrypted; the photo files it
   references are not.
3. **Kotlin Gradle Plugin deprecation.** Builds today; a future Flutter release
   will refuse it until several plugins are upgraded (`android/gradle.properties`).

Checked and **safe in release**: the static check-in position, the demo outlet
pin, Firebase "check-only" password reset, the pricing and device-registry
console dumps, and the integration debug logs. Each is compiled out by
`kDebugMode` / `kReleaseMode`. Mock data is off unless
`--dart-define=USE_MOCK_DATA=true` is passed. The mock SAP master-data source is
registered but no screen calls it. App Check uses reCAPTCHA in release, not the
debug provider. Cleartext HTTP and user-installed CAs are refused in release.
