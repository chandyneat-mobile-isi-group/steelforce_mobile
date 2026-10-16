# Android release — signed AAB and Firebase App Distribution

> **Purpose:** how to build a signed Android App Bundle locally and hand it to
> QA through Firebase App Distribution, and what a future GitLab CI/CD job will
> need. **Nothing here is automated yet** — no `.gitlab-ci.yml` exists.
> **Never document a secret here.** Variable *names* only.

---

## 1. Identity

| Item | Value | Source |
|---|---|---|
| applicationId / namespace | `com.isigroup.steelforce` | `android/app/build.gradle.kts` |
| Firebase project | `steelforce-94963` | `android/app/google-services.json` |
| Firebase Android App ID | `1:696334570059:android:f1a7010fb960234bb0f3ce` | `android/app/google-services.json` |
| versionName / versionCode | `version: X.Y.Z+N` in `pubspec.yaml` | Flutter → `flutter.versionName` / `flutter.versionCode` |
| Flavors | none | |

The applicationId is permanent once a build is distributed — do not change it.

**Versioning.** Bump `pubspec.yaml` before every distributed build. `N`
(versionCode) must **always increase** — Firebase and Play both reject or
mis-order a build that reuses one. It may also be overridden per build without
editing the file: `flutter build appbundle --release --build-number=35`.

---

## 2. Release keystore (one time)

The release (upload) keystore is created **once**, by the release owner, and
stored in the company password vault. Losing it means losing the ability to
ship updates to existing installs.

```bash
keytool -genkeypair -v \
  -keystore ~/secure/steelforce-upload.jks \
  -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

> `keytool` ships with Android Studio:
> `"/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool"`.

Keep the `.jks` **outside the repository**. `.gitignore` blocks `*.jks`,
`*.keystore`, `*.p12` and `key.properties` anywhere in the tree as a backstop,
not as the plan.

### Local signing

```bash
cp android/key.properties.example android/key.properties
# edit: storeFile (absolute path), storePassword, keyAlias, keyPassword
```

`storeFile` is resolved relative to `android/app/`; prefer an absolute path.

### How Gradle chooses the key — `android/app/build.gradle.kts`

1. `ANDROID_KEYSTORE_PATH` set → sign from environment variables (CI path).
2. else `android/key.properties` present → sign from it (local path).
3. else → **debug and profile builds work normally**; any release packaging
   task (`bundleRelease`, `assembleRelease`, …) **fails** with an explicit
   message. A release artifact is never silently signed with the debug key.

If signing material is present but incomplete (a blank password, a keystore
path that does not exist), the build fails naming the missing input — never
its value.

---

## 3. Build

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # needs .env
flutter analyze
flutter test
flutter build appbundle --release
```

Output: **`build/app/outputs/bundle/release/app-release.aab`**

Verify the signature (prints the certificate; must not be `CN=Android Debug`):

```bash
jarsigner -verify -verbose:summary -certs build/app/outputs/bundle/release/app-release.aab
keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab
```

`google-services.json` is git-ignored, so a fresh clone does not have it —
`processReleaseGoogleServices` fails until it is provided (§5).

---

## 4. Firebase App Distribution (manual, today)

Tool: the official **Firebase CLI** (`npm install -g firebase-tools`). It is a
machine tool, not a project dependency — nothing is added to `pubspec.yaml`.

```bash
firebase login        # interactive, local only
firebase appdistribution:distribute build/app/outputs/bundle/release/app-release.aab \
  --app 1:696334570059:android:f1a7010fb960234bb0f3ce \
  --release-notes-file release-notes.txt \
  --groups "qa"
```

Release notes: copy [release-notes.template.txt](release-notes.template.txt)
to a local `release-notes.txt` and fill it in. The `qa` group must exist in
Firebase console → App Distribution → Testers & Groups.

> ⚠️ **AAB prerequisite.** Firebase distributes an AAB through Google Play
> internal app sharing, so the Firebase project must be **linked to a Google
> Play developer account** and the app `com.isigroup.steelforce` must exist in
> Play Console (Firebase console → Project settings → Integrations → Google
> Play). Until that link exists, an AAB upload is rejected; distribute an APK
> instead with the same command:
> `flutter build apk --release` → `build/app/outputs/flutter-apk/app-release.apk`.

---

## 5. Credentials a future GitLab CI/CD job will need

Configure as **masked + protected** GitLab CI/CD variables (Settings → CI/CD →
Variables). None exist yet.

| Variable | Type | Purpose |
|---|---|---|
| `ANDROID_KEYSTORE_BASE64` | Variable (masked) | `base64 -i steelforce-upload.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | Variable (masked) | Keystore password |
| `ANDROID_KEY_ALIAS` | Variable | Key alias (`upload`) |
| `ANDROID_KEY_PASSWORD` | Variable (masked) | Key password |
| `GOOGLE_SERVICES_JSON` | **File** | Contents of `android/app/google-services.json` |
| `DOTENV_FILE` | **File** | Production `.env` (Envied input) |
| `FIREBASE_SERVICE_ACCOUNT` | **File** | Service-account JSON with the **Firebase App Distribution Admin** role |

`FIREBASE_TOKEN` (`firebase login:ci`) is deprecated — use the service account.
The Firebase CLI picks it up through `GOOGLE_APPLICATION_CREDENTIALS`.

The job then only has to materialise those into the paths this repo already
expects — **no Gradle change is needed**:

```bash
echo "$ANDROID_KEYSTORE_BASE64" | base64 -d > "$CI_PROJECT_DIR/upload.jks"
export ANDROID_KEYSTORE_PATH="$CI_PROJECT_DIR/upload.jks"
cp "$GOOGLE_SERVICES_JSON" android/app/google-services.json
cp "$DOTENV_FILE" .env
dart run build_runner build --delete-conflicting-outputs
flutter build appbundle --release --build-number="$CI_PIPELINE_IID"
GOOGLE_APPLICATION_CREDENTIALS="$FIREBASE_SERVICE_ACCOUNT" \
  firebase appdistribution:distribute build/app/outputs/bundle/release/app-release.aab \
    --app 1:696334570059:android:f1a7010fb960234bb0f3ce \
    --release-notes-file release-notes.txt --groups "qa"
```

Planned pipeline: `test` (format, analyze, `flutter test`) → `build` (signed
AAB, artifact) → `distribute` (Firebase, `develop` branch only, manual or
automatic). Note `test/` is currently git-ignored (root `.gitignore`), so the
test stage cannot run until it is tracked again.
