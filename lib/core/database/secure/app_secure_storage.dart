import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The one configuration of `flutter_secure_storage` the app uses. Every
/// instance — DI, Hive's key, the migration — must be built here, or two
/// instances write the same key with different protection.
///
/// * **Android** — `encryptedSharedPreferences`: values are encrypted with a
///   Keystore-held key.
/// * **iOS** — `first_unlock_this_device`: readable after the first unlock
///   since boot (background sync runs while the phone is locked in a pocket)
///   and **never leaves this device** — not in an iCloud/encrypted backup, not
///   through Quick Start to a new phone. A token or database key that follows
///   a backup onto another handset defeats the device binding the database
///   encryption relies on (`docs/blueprint/local-storage-architecture.md` §2).
///
/// Items written before this setting keep their old protection until
/// rewritten; `KeychainAccessibilityMigration` does that once.
FlutterSecureStorage appSecureStorage() => const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
      ),
    );
