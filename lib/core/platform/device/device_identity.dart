import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:steelforce/core/database/secure/secure_storage_keys.dart';
import 'package:steelforce/core/localization/active_language.dart';
import 'package:steelforce/core/platform/device/device_os.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/core/utils/uuid.dart';

/// Builds the `device` block sent with `POST /auth/login` and the bare
/// `deviceId` sent with `POST /auth/refresh`.
///
/// The user types none of this. Its whole purpose is to turn the session list
/// at `GET /auth/sessions` from a column of GUIDs into something a
/// representative can act on when they lose a handset, and to give support a
/// device string to look at when someone reports "the app crashed this
/// morning".
///
/// **[deviceId] identifies an installation, not a person, and is never used
/// for authorisation.** It must survive app restarts — hence secure storage
/// rather than an in-memory field — but it is expected to change on reinstall.
class DeviceIdentity {
  DeviceIdentity(this._storage);

  final FlutterSecureStorage _storage;

  /// Memoised so a burst of parallel refreshes does not race on first write.
  Future<String>? _pending;

  /// The stable per-installation identifier, minted on first call.
  ///
  /// The same value must go to `/auth/login` and every subsequent
  /// `/auth/refresh`, otherwise the rotation detaches from the session record
  /// the server is tracking.
  Future<String> deviceId() => _pending ??= _readOrCreate();

  Future<String> _readOrCreate() async {
    try {
      final existing = await _storage.read(key: SecureStorageKeys.kDeviceId);
      if (existing != null && existing.isNotEmpty) return existing;

      final minted = Uuid.v4();
      await _storage.write(key: SecureStorageKeys.kDeviceId, value: minted);
      return minted;
    } catch (_) {
      // Secure storage can fail on a device with a broken keystore. A
      // per-run identifier still lets sign-in succeed; the user simply gets a
      // new session row each launch, which is far better than being unable to
      // sign in at all.
      return Uuid.v4();
    }
  }

  /// The optional `device` object for the login body.
  ///
  /// [pushToken] is threaded through from the messaging layer when one has
  /// been granted; it is omitted rather than sent empty when it has not.
  Future<DataMap> describe({
    String? pushToken,
    bool rememberDevice = true,
  }) async {
    final id = await deviceId();
    return <String, dynamic>{
      'deviceId': id,
      'deviceName': _deviceName(),
      'platform': _platform(),
      if (readOsVersion() case final os?) 'osVersion': os,
      'appVersion': appVersion,
      'timeZone': _timeZone(),
      'language': _languageTag(),
      if (pushToken != null && pushToken.isNotEmpty) 'pushToken': pushToken,
      'rememberDevice': rememberDevice,
    };
  }

  /// Build identity, injectable at compile time so CI can stamp the real
  /// build number: `flutter build --dart-define=APP_VERSION=1.4.2+310`.
  /// The fallback tracks `version:` in `pubspec.yaml`.
  static const String appVersion =
      String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0+1');

  String _deviceName() => readHostName() ?? '${_platform()} device';

  String _platform() => switch (defaultTargetPlatform) {
        TargetPlatform.android => 'Android',
        TargetPlatform.iOS => 'iOS',
        TargetPlatform.macOS => 'macOS',
        TargetPlatform.windows => 'Windows',
        TargetPlatform.linux => 'Linux',
        TargetPlatform.fuchsia => 'Fuchsia',
      };

  /// Dart core exposes only the zone abbreviation (`ICT`, `+07`), not the IANA
  /// name the API example shows (`Asia/Phnom_Penh`). The server treats this as
  /// a display hint on the session row, so the abbreviation is adequate;
  /// swap in `flutter_timezone` here if an exact IANA name is ever required.
  String _timeZone() => DateTime.now().timeZoneName;

  /// BCP 47 tag matching what the app sends as `Accept-Language`.
  String _languageTag() => ActiveLanguage.acceptLanguageTag;
}
