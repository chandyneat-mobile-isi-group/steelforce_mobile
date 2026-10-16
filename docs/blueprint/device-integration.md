# Device Integration

> **Purpose:** every device capability the app touches — what it is for, which
> permission it needs, which platforms support it, where it is implemented, and
> what happens when it is denied or unavailable.
> **Source:** `pubspec.yaml`, `android/app/src/main/AndroidManifest.xml`,
> `ios/Runner/Info.plist`, and `lib/` on 2026-08-27.

Field sales is the whole reason this section exists: a rep standing in a depot
aisle with one bar of signal and a declined location permission must still be
able to work. **Every capability below degrades; none of them blocks.**

---

## Declared permissions

### Android — `AndroidManifest.xml`

| Permission | Needed by |
|---|---|
| `INTERNET`, `ACCESS_NETWORK_STATE` | `dio`, `connectivity_plus` |
| `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION` | Geofenced check-in, stop distance sorting |
| `ACCESS_BACKGROUND_LOCATION` | Route telemetry while the app is backgrounded |
| `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION` | Keeps telemetry alive during a route |
| `WAKE_LOCK` | Same |
| `CAMERA` | Document and drawing capture via `image_picker` |
| `READ_MEDIA_IMAGES`, `READ_MEDIA_VIDEO`, `READ_MEDIA_AUDIO` | Gallery selection (Android 13+ scoped media) |
| `RECORD_AUDIO` | Voice search (`speech_to_text`) |
| `POST_NOTIFICATIONS` | Push and local notifications (Android 13+ runtime prompt) |

### iOS — `Info.plist`

| Usage description | Needed by |
|---|---|
| `NSLocationWhenInUseUsageDescription` | Check-in, distance sorting |
| `NSLocationAlwaysAndWhenInUseUsageDescription` | Background route telemetry |
| `NSCameraUsageDescription` | Document / drawing capture |
| `NSPhotoLibraryUsageDescription` | Gallery selection |
| `NSMicrophoneUsageDescription` | Voice search |
| `NSSpeechRecognitionUsageDescription` | Voice search transcription |

> `READ_MEDIA_VIDEO` and `READ_MEDIA_AUDIO` are declared but nothing in `lib/`
> selects video or audio files. Narrowing them is a Play-Store-review win and a
> privacy improvement. Unverified whether an Android 13 media-picker path needs
> them incidentally — check before removing.

---

## Capability register

| Capability | Package | Implemented in | Android | iOS | Web |
|---|---|---|---|:-:|:-:|:-:|
| Location — one-shot | `geolocator` | `features/order/presentation/services/geolocator_order_location_service.dart` | ✅ | ✅ | ✅ browser API |
| Location — continuous telemetry | `geolocator` | `features/my_visits/data/services/geolocator_tracking_service.dart` | ✅ | ✅ | ⚠ no background |
| Maps | `google_maps_flutter` | `features/my_visits/presentation/widgets/transit_map.dart` | ✅ | ✅ (needs `GOOGLE_MAPS_IOS_KEY`) | ❌ |
| Camera / gallery | `image_picker` | `add_depot_bottom_sheet.dart`, `drawing_upload_component.dart`, `customization_cubit.dart`, `image_picker_search_service.dart` | ✅ | ✅ | ⚠ file input |
| Save image to gallery | `gal` | `stop_information_screen.dart` | ✅ | ✅ | ❌ |
| Speech → text | `speech_to_text` | `features/order/presentation/screens/catalog/voice_search_screen.dart` | ✅ | ✅ | ⚠ browser-dependent |
| PDF generation | `pdf` | `core/services/pdf/` | ✅ | ✅ | ✅ |
| PDF print / share | `printing` | `core/services/pdf/pdf_share_service.dart` | ✅ | ✅ | ✅ browser print |
| Open a saved file | `open_filex` | `core/services/pdf/pdf_opener_native.dart` | ✅ | ✅ | ❌ download instead |
| App-private file storage | `path_provider` | `encrypted_database.dart`, `captured_media_store_native.dart`, `pdf_file_store_native.dart` | ✅ | ✅ | ❌ blob URLs |
| Push notifications | `firebase_messaging` | `core/notifications/push/push_messaging_service_native.dart` | ✅ | ✅ | ❌ no-op |
| Local / foreground alerts | `flutter_local_notifications` | `core/notifications/local/local_notification_presenter_native.dart` | ✅ | ✅ | ❌ no-op |
| Device IANA time zone | `flutter_timezone` | `core/notifications/device_time_zone.dart` | ✅ | ✅ | ✅ |
| Connectivity + real reachability | `connectivity_plus` | `core/network/connectivity/connectivity_service.dart`, `network_info.dart`, `connectivity_cubit.dart` | ✅ | ✅ | ✅ |
| Secure key storage | `flutter_secure_storage` | `core/database/secure/` | ✅ Keystore | ✅ Keychain | ⚠ not hardware-backed |
| Barcode scanning | `mobile_scanner` | **interface only** — `features/order/domain/services/barcode_scanner_service.dart` | ✗ | ✗ | ✗ |

Every native capability is reached through a **conditional import** pair
(`*_native.dart` / `*_web.dart` behind a `*_factory.dart`), so the web target
compiles without any of them. See
[web-architecture.md](web-architecture.md).

---

## Failure behaviour

Denial is a normal state, not an error path.

| Capability | Denied / unavailable |
|---|---|
| Location (check-in) | Check-in is still recorded; the geofence verdict is marked unverified rather than blocking the visit. See [../feature/my-visits/architecture.md](../feature/my-visits/architecture.md). |
| Background location | Telemetry gaps while backgrounded; the route still completes. |
| Camera / gallery | Attachment step is skippable; the depot or quotation saves without it. |
| Microphone / speech | Voice search falls back to the text field. |
| Notifications | The **inbox is the notification** — push only accelerates it. A rep who declines the prompt still sees everything on next sync. |
| Maps | Stops remain usable as a list; only the map widget is absent. |
| Secure storage | Fail-closed: the encrypted database refuses to open rather than falling back to plaintext. |
| Connectivity | The entire app is designed for this — see [offline-architecture.md](offline-architecture.md). |

The notification permission has an explainer card
(`features/notification/presentation/widgets/push_permission_card.dart`) shown
before the OS prompt, with `isi.push_explainer_shown_at` recording that it was
shown so the rep is not re-nagged.

---

## Privacy and security

- Captured media goes to app-private storage via `path_provider` and, for
  sensitive attachments, through `core/database/files/encrypted_file_store.dart`.
  Never to shared external storage.
- Location samples are business data: they live in the **encrypted** Drift
  database (`route_telemetry` via `route_telemetry_dao.dart`), never in Hive or
  preferences.
- `LogRedactor` masks coordinates, phone numbers, e-mail, and depot data by
  key name and value shape. Never log a raw position or a raw payload — see
  [../skills/security.md](../skills/security.md) §10.
- The IANA zone (`Asia/Phnom_Penh`) is sent to the backend so quiet hours and
  digests land on the rep's wall clock. Dart's core library exposes only the
  abbreviation (`ICT`), which is why `flutter_timezone` is a dependency.

---

## Unused declared dependencies

Present in `pubspec.yaml`, referenced nowhere in `lib/` as of 2026-08-27:

| Package | Status |
|---|---|
| `geocoding` | Unused. The `geo_location` feature resolves addresses from the **bundled offline gazetteer** (`assets/geo/`) and imports no geocoding plugin — which is the correct offline-first choice. |
| `file_picker` | Unused. Attachments go through `image_picker`. |
| `fl_chart` | Unused. The KPI screen does not chart. |
| `mobile_scanner` | Named only in a doc comment; `MobileBarcodeScannerService` is not implemented. |

Each still ships native code and, for `mobile_scanner`, motivates the `CAMERA`
permission. Removing them shrinks the binary and the permission surface. Not
done here — dependency removal is a code change outside a documentation pass.

---

## Related

- [offline-architecture.md](offline-architecture.md) — the connectivity posture these capabilities assume
- [web-architecture.md](web-architecture.md) — how each native capability is no-op'd for the browser
- [../skills/security.md](../skills/security.md) — storage, logging, and privacy rules
- [../feature/notification/README.md](../feature/notification/README.md) — push registration and the ten channels
- [../feature/my-visits/architecture.md](../feature/my-visits/architecture.md) — geofence and telemetry design
