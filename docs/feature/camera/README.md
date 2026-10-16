# Camera — Mock and Real

**Purpose:** how the app acquires a photograph, and why the iOS Simulator gets a stand-in.
**Scope:** `lib/core/camera/`, and the four features that capture images.
**Status:** Active · **Last updated:** 2026-08-31

---

## Why this exists

The iOS Simulator has **no camera at all**. `image_picker` opens and returns
nothing, so every flow that needs a photograph was untestable there:

| Feature | What it captures |
|---|---|
| Depot registration | Storefront, inside-store, ID card, patent/tax, VAT certificate |
| Visit proof photo | A timestamped, GPS-stamped shot at a stop |
| Quotation drawing upload | A depot's sketch or drawing |
| Visual product search | A photo matched against the catalogue |

Rather than each of those learning what a simulator is, one seam decides where
pixels come from and hands back the same type either way.

---

## The seam

```text
Feature (depot evidence, proof photo, drawing, visual search)
        ↓
ImageCaptureService            ← the only thing features know about
        ↓
CameraFactory                  ← the only place the environment is consulted
        ↓
RealImageCaptureService   or   MockImageCaptureService
        ↓                              ↓
   device camera              bundled test images
```

Both return `XFile?` — the same type, backed by a **real file** — so the
stamping, compression, validation and upload downstream are byte-identical.
A mock image travels the same path as a real one; nothing branches on origin.

**No feature may ask whether it is on a simulator.** If you find yourself
writing `if (Platform.isIOS)` in a screen, the seam is the answer instead.

---

## Which implementation runs

| Environment | Implementation | Why |
|---|---|---|
| Physical iOS device | Real | It has a camera |
| Physical Android device | Real | It has a camera |
| **iOS Simulator** | **Mock** | No camera hardware exists |
| Android emulator | Real | Its emulated camera works, and `image_picker` drives it |
| Web | Real | `image_picker` falls back to a file input, which is correct there |

Android-emulator detection would need `device_info_plus` — a dependency added
to answer one boolean, to route around a camera that already works. A developer
who wants the stand-in there asks for it explicitly (below).

### How the Simulator is detected

By **path**, not by environment variable:

```text
Simulator app bundle   /Users/<you>/Library/Developer/CoreSimulator/Devices/<UDID>/…/Runner.app
Physical device bundle /private/var/containers/Bundle/Application/<GUID>/Runner.app
```

`Platform.resolvedExecutable` and the sandboxed `HOME` both carry the
`CoreSimulator` segment on a simulator and neither does on a handset.

> **Why not `SIMULATOR_DEVICE_NAME`?** It was the first implementation and it
> did not work. Those variables are set for processes launched *through*
> `simctl` — `xcrun simctl spawn booted /usr/bin/env` shows them — but a Flutter
> app is launched by the simulator's SpringBoard and inherits none of them.
> Detection returned false, the factory handed out the real camera, and iOS
> answered with its own *"Camera not available"* alert. The check is kept as a
> cheap extra signal; the paths are what actually decide.
>
> `test/core/platform/simulator_detection_test.dart` pins both path shapes
> against real values from `xcrun simctl get_app_container`.

---

## Configuration

```bash
flutter run                                  # auto — the default
flutter run --dart-define=CAMERA_MODE=mock   # force the stand-in
flutter run --dart-define=CAMERA_MODE=real   # force the device camera
```

`auto` is the default deliberately: a build that silently defaults to mock is a
build that uploads placeholder images as depot evidence. An unrecognised
value falls back to `auto` rather than throwing at startup.

Mirrors the existing `USE_MOCK_DATA` switch — see `core/config/data_source_mode.dart`.

---

## The mock camera

It behaves like a camera rather than showing a list, because the flow being
tested is *frame → capture → the image comes back*:

```text
┌──────────────────────────────┐
│  ✕            Camera         │
│  ┌────────────────────────┐  │
│  ⌐                      ¬  │  │
│                             │  │
│        test image           │  │
│  ⌐                      ¬  │  │
│  └────────────────────────┘  │
│    MOCK CAMERA · simulator   │
│                              │
│ [Storefront][Inside][ID]…    │
│           ( ● )              │
└──────────────────────────────┘
```

Capture → **Retake** / **Use photo**. Cancelling returns `null`, exactly as the
real picker does, so every caller's existing cancel path already handles it.

The amber badge reads `simulator` when the mode was chosen automatically and
`forced` when someone passed `CAMERA_MODE=mock` — so a forced mock on a real
handset is never mistaken for automatic behaviour.

---

## Test images

`assets/mock/camera/` — synthetic, drawn programmatically. **No real depot
photographs, documents or personal information is bundled with the app.**

| File | Slot it stands in for |
|---|---|
| `storefront.png` | Depot storefront evidence |
| `inside_store.png` | Inside-store evidence |
| `id_card.png` | ID card evidence |
| `document.png` | Patent / tax / VAT document |
| `material.png` | Material photo, visual search |

### Adding one

1. Drop the file in `assets/mock/camera/`.
2. Add a value to `MockCameraAsset` with its filename and a label.

That is all — the picker, the preview and the selector are all driven from the
enum. `pubspec.yaml` already lists the directory; **it needs its own line
because Flutter does not recurse into subdirectories**, which is exactly how a
new image goes silently missing.

A missing or empty asset throws `MockCameraAssetException` with the pubspec
hint rather than returning null — null would be indistinguishable from a
developer cancelling the camera.

---

## Testing a camera-dependent feature

```bash
flutter run                                   # on the Simulator: mock, automatically
flutter run --dart-define=CAMERA_MODE=mock    # on a device, to exercise the stand-in
```

Capture as normal. The image reaches the same processing, validation and upload
path a real photograph would — that is the property the seam exists to
guarantee, and `test/core/camera/mock_camera_integration_test.dart` asserts it.

---

## Turning it off

Nothing to turn off: `auto` already selects the real camera everywhere except
the Simulator. To prove a build uses the real camera, run with
`--dart-define=CAMERA_MODE=real` — the factory then never constructs the mock.

---

## Files

| File | Role |
|---|---|
| `core/camera/image_capture_service.dart` | The seam features depend on |
| `core/camera/camera_factory.dart` | The only place the environment is consulted |
| `core/camera/camera_mode.dart` | `CAMERA_MODE` parsing and resolution |
| `core/camera/real_image_capture_service.dart` | `image_picker` pass-through |
| `core/camera/mock/mock_image_capture_service.dart` | Bundled assets → real files |
| `core/camera/mock/mock_camera_screen.dart` | The stand-in camera UI |
| `core/camera/mock/mock_camera_asset.dart` | The test-image catalogue |
| `core/platform/runtime_environment*.dart` | Simulator detection |

---

## See also

- [../depot/mobile/depot-documents.md](../depot/mobile/depot-documents.md) — the evidence upload this feeds
- [../../skills/security.md](../../skills/security.md) §3 — why no real documents are bundled
