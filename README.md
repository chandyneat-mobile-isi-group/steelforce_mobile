<div align="center">

<img src="assets/logos/steelforce_app_logo.png" alt="SteelForce" width="96" />

# SteelForce

**Offline-first field sales platform for ISI Steel, a member of ISI GROUP.**

[![Version](https://img.shields.io/badge/Version-1.0.0-1F6FEB)](pubspec.yaml)
[![Flutter](https://img.shields.io/badge/Flutter-3.44-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.12-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Architecture](https://img.shields.io/badge/Architecture-Clean%20%2B%20BLoC-6E56CF)](docs/blueprint/system-architecture.md)
[![Storage](https://img.shields.io/badge/Storage-Drift%20%2B%20SQLCipher-1FA37A)](docs/blueprint/local-storage-architecture.md)
[![License](https://img.shields.io/badge/License-Proprietary-C7362F)](#license)

</div>

---

## Overview

SteelForce is the mobile workspace for the steel distribution sales force. Reps
manage depots, run their daily visit routes, check in on site with GPS and photo
proof, and prepare quotations and sales orders that flow into SAP.

It is built for places where connectivity is unreliable — warehouses, factory
yards, rural routes. **Every read is served from an encrypted on-device
database and every write succeeds locally first**; synchronisation with the
backend happens opportunistically when the network returns.

| | |
|---|---|
| **Domain** | Steel distribution · field sales · SAP-backed order-to-cash |
| **Platforms** | Android · iOS · Web (internal preview) |
| **Languages** | English · ភាសាខ្មែរ (Khmer) |
| **Identifiers** | Android `com.isigroup.steelforce` · iOS `com.isigroup.steelforce` |

---

## Core Features

| Area | Capabilities |
|---|---|
| **Authentication** | Guest-first access, secure sign-in, password recovery, hardware-backed token storage, full data wipe on sign-out |
| **Depots** | Depot directory with search, filters and favourites; depot detail (overview, sales, promotions); guided customer registration with GPS and document capture |
| **Visits** | Daily route dashboard, geofenced check-in with proof photos, inventory capture, check-out outcomes, ad-hoc visits, map view |
| **Orders** | Product catalogue, cart, quotations with PDF preview, sales orders |
| **Offline & sync** | Local-first writes, transactional sync queue, connectivity banner, Sync Center with retry |
| **Notifications** | In-app inbox with push (FCM) acceleration and deep links |
| **Profile & settings** | Light/dark theme, runtime language switching, password change |

---

## Architecture

Clean Architecture, three layers per feature, dependencies pointing **inward only**.

```
┌──────────────────────────────────────────────────────────────┐
│  Presentation  — screens · widgets · BLoC/Cubit              │
├──────────────────────────────────────────────────────────────┤
│  Domain        — entities · repository interfaces · usecases │
├──────────────────────────────────────────────────────────────┤
│  Data          — repository impls · Drift DAOs · API clients │
├──────────────────────────────────────────────────────────────┤
│  Core          — database · network · sync · session · di    │
│                  theme · localization · logging · responsive │
└──────────────────────────────────────────────────────────────┘
```

Each feature registers itself through `lib/features/<feature>/<feature>_injection.dart`,
composed in [injection_container.dart](lib/core/di/injection_container.dart).
Startup runs through a single [app_bootstrap_service.dart](lib/core/bootstrap/app_bootstrap_service.dart),
which performs no network I/O, so the app starts identically offline.

### Data storage

| Data | Store | Protection |
|---|---|---|
| Business data — depots, routes, visits, orders, sync queue | Drift (SQLite) | SQLCipher encryption |
| Tokens, cached user, device key | `flutter_secure_storage` | Android Keystore / iOS Keychain |
| Non-sensitive preferences | Hive | Never holds PII or tokens |

The database key is derived at runtime from a build-time salt and a device-bound
key sealed in the platform keystore; opening the database is fail-closed. Detail:
[local-storage-architecture.md](docs/blueprint/local-storage-architecture.md).

### Offline-first

A local change and its sync-queue entry are written **in the same transaction**
(ADR-0006), so no change can be lost between saving and syncing. Connectivity is
judged by real reachability, not interface state (ADR-0005). See
[offline-architecture.md](docs/blueprint/offline-architecture.md) and
[sync-architecture.md](docs/blueprint/sync-architecture.md).

---

## Tech Stack

| Concern | Choice |
|---|---|
| **Framework** | Flutter 3.44 · Dart 3.12 |
| **State** | `flutter_bloc` · `bloc_concurrency` · `equatable` |
| **DI** | `get_it` |
| **Database** | `drift` · `sqlcipher_flutter_libs` |
| **Secrets & config** | `flutter_secure_storage` · `envied` (compile-time obfuscated) |
| **Preferences** | `hive_flutter` |
| **Networking** | `dio` · `connectivity_plus` |
| **Location & maps** | `geolocator` · `google_maps_flutter` |
| **Capture** | `image_picker` · `speech_to_text` |
| **Documents** | `pdf` · `printing` · `open_filex` |
| **Notifications** | `firebase_messaging` · `flutter_local_notifications` |
| **Background work** | `workmanager` |
| **UI** | Material 3 · `flutter_screenutil` · `lottie` · `cached_network_image` · ABC Ginto + MiSans Khmer |

---

## Getting Started

### Prerequisites

- Flutter **3.44** (stable) · Dart **3.12**
- Android Studio with Android SDK 36 (min SDK 24)
- Xcode and CocoaPods for iOS builds

### 1 · Install dependencies

```bash
flutter pub get
```

### 2 · Configure the environment

Configuration is compiled in and obfuscated by [Envied](lib/core/config/env.dart).
Copy the template and fill in the values supplied by the release owner:

```bash
cp .env.example .env
```

`.env` is git-ignored and must never be committed. Every key is documented in
[`.env.example`](.env.example) and [environment.md](docs/release/environment.md).

> **`DB_SALT` must stay stable per environment.** Changing it makes every
> existing on-device database unreadable.

Firebase configuration files (`android/app/google-services.json`,
`ios/Runner/GoogleService-Info.plist`) are distributed out of band.

### 3 · Generate code

```bash
dart run build_runner build --delete-conflicting-outputs   # Drift, Envied, JSON
dart run tool/generate_ios_env.dart                        # iOS only: .env → Env.xcconfig
```

### 4 · Run

```bash
flutter run
```

---

## Building for Release

### Android

Release builds are signed with the SteelForce release keystore through a
git-ignored `android/key.properties` (template:
[key.properties.example](android/key.properties.example)) or CI environment
variables. A release build **fails** rather than falling back to the debug key.

```bash
flutter build appbundle --release            # Play Store
flutter build apk --release --split-per-abi  # Firebase App Distribution (QA)
```

| Artifact | Path |
|---|---|
| App Bundle | `build/app/outputs/bundle/release/app-release.aab` |
| APK (arm64) | `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` |

Full procedure — keystore, signing, Firebase App Distribution, release notes:
[android-release.md](docs/release/android-release.md).

### iOS

```bash
dart run tool/generate_ios_env.dart
flutter build ipa --release
```

### Versioning

Versions follow `MAJOR.MINOR.PATCH+BUILD` in [pubspec.yaml](pubspec.yaml). The
build number must increase for every distributed build.

---

## Quality Checks

Run before every release:

```bash
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

The release gate checklist is in [docs/release/README.md](docs/release/README.md).
QA test cases for Firebase App Testing live in `QA-engineering/` (kept outside
the repository).

---

## Project Structure

```
lib/
├── core/            shared infrastructure — database, network, sync, session,
│                    di, theme, localization, notifications, permissions, …
├── features/        one folder per feature: data/ · domain/ · presentation/
│   ├── authentication   depots   my_visits   order   shell
│   ├── notification     profile  settings    localization
│   └── about  app_coach  geo_location  onboarding  splash
├── shared/          widgets and animations used by more than one feature
├── routes/          navigation
├── app.dart
└── main.dart
android/  ios/  web/  assets/  docs/  tool/
```

---

## Documentation

| Document | Contents |
|---|---|
| [engineering-standard.md](docs/skills/engineering-standard.md) | Master engineering rules |
| [system-architecture.md](docs/blueprint/system-architecture.md) | Layers, dependencies, folder structure |
| [local-storage-architecture.md](docs/blueprint/local-storage-architecture.md) | Database schema, encryption, key handling |
| [offline-architecture.md](docs/blueprint/offline-architecture.md) | Offline behaviour per domain |
| [sync-architecture.md](docs/blueprint/sync-architecture.md) | Sync queue, retry, conflict resolution |
| [security.md](docs/skills/security.md) | Security controls and release gates |
| [docs/release/](docs/release) | Environment, Android release, CI/CD |
| [docs/adr/](docs/adr) | Architecture decision records |
| [docs/feature/](docs/feature) | Per-feature specifications |

---

## Security

- Never commit `.env`, `Env.xcconfig`, keystores, `key.properties`, Firebase
  service-account files or any generated secret material — all are git-ignored.
- No tokens, credentials or customer data are written to logs in release builds.
- Report security concerns to the Mobile Engineering team rather than opening a
  public issue.

---

## License

Proprietary — © ISI Steel, a member of ISI GROUP. Internal use only. All rights reserved.
