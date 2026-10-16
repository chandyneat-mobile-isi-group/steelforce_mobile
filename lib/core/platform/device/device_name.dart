import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

/// The handset's real model name, for the push device registry.
///
/// ## Why `Platform.localHostname` was not good enough
///
/// `readHostName()` — the previous source — answers **`localhost`** on Android.
/// So every Android registration in the device registry read `localhost`, and
/// `docs/feature/notification/api/devices-register.md` describes this field as
/// the *"label shown in the device registry"*: the thing support reads when a
/// rep says they stopped receiving notifications. A column of identical
/// `localhost` rows makes the registry unusable for the one job it has.
///
/// `dart:io` cannot answer this — there is no model name in it — which is why
/// `device_info_plus` is a dependency rather than something hand-rolled.
///
/// ## What is deliberately not used
///
/// On iOS, `IosDeviceInfo.name` returns the **user-assigned** device name —
/// "Dara's iPhone". That is personal information about a named individual, and
/// `docs/skills/security.md` §10 keeps personal information out of anything
/// support-visible or logged. The model (`iPhone 15 Pro`) identifies the handset
/// just as well for triage without naming its owner.
///
/// Android's `model` is already a product name (`Pixel 8`, `SM-A546E`), so the
/// manufacturer is prepended only when the model does not already contain it —
/// `Samsung SM-A546E` is useful, `Google Google Pixel 8` is not.
///
/// ## Failure returns null, never a placeholder
///
/// The field is optional, and `NotificationApiMapper.registrationToJson` omits
/// it when absent. An absent label tells support "this build could not read the
/// model"; a fabricated `"Android device"` tells them nothing while looking
/// like an answer — which is exactly the state this replaces.
Future<String?> readDeviceName() async {
  // No model to report, and `device_info_plus` on web would answer with a
  // user-agent string — a fingerprint rather than a device label.
  if (kIsWeb) return null;

  try {
    final plugin = DeviceInfoPlugin();

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        final info = await plugin.androidInfo;
        return _clamp(_android(info.manufacturer, info.model));

      case TargetPlatform.iOS:
        final info = await plugin.iosInfo;
        // `utsname.machine` is the hardware identifier (`iPhone16,1`) and
        // `model` the generic class (`iPhone`). Neither is as readable as
        // `name`, but `name` is the owner's — see the note above. The two
        // together are unambiguous for triage.
        return _clamp(_join([info.model, info.utsname.machine]));

      case TargetPlatform.macOS:
        final info = await plugin.macOsInfo;
        return _clamp(info.model);

      case TargetPlatform.windows:
        final info = await plugin.windowsInfo;
        return _clamp(info.productName);

      case TargetPlatform.linux:
        final info = await plugin.linuxInfo;
        return _clamp(info.prettyName);

      case TargetPlatform.fuchsia:
        return null;
    }
  } catch (_) {
    // A platform channel can fail on an OEM build with a stripped provider.
    // Swallowed silently and deliberately: this runs on every launch, so a
    // permanently broken channel would fill the log with a line nobody can act
    // on, and the absent field is already visible in the registry — which is
    // where a support engineer would actually look.
    return null;
  }
}

/// `Samsung SM-A546E`, but `Pixel 8` rather than `Google Google Pixel 8`.
String? _android(String manufacturer, String model) {
  final make = manufacturer.trim();
  final name = model.trim();
  if (name.isEmpty) return make.isEmpty ? null : make;
  if (make.isEmpty) return name;

  // Case-insensitive: Android reports `samsung` in lower case while the model
  // carries `SM-`, and Google reports `Google` against a `Pixel 8` model.
  if (name.toLowerCase().contains(make.toLowerCase())) return name;
  return '$make $name';
}

String? _join(List<String> parts) {
  final kept = parts.map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
  return kept.isEmpty ? null : kept.join(' ');
}

/// The registry's documented ceiling for this field.
///
/// A longer value answers `400 General.Validation` and takes the **whole
/// registration** down with it — token included — so the handset would stop
/// receiving notifications because its name was verbose. Truncating is the
/// obviously better trade.
String? _clamp(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed.length <= maxDeviceNameLength
      ? trimmed
      : trimmed.substring(0, maxDeviceNameLength);
}

/// `deviceName` max length, per the device-registration contract.
const int maxDeviceNameLength = 128;
