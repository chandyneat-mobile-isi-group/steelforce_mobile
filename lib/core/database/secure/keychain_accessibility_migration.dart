import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:steelforce/core/database/secure/secure_storage_keys.dart';
import 'package:steelforce/core/logging/app_logger.dart';

/// Re-protects Keychain items written before [appSecureStorage] set
/// `first_unlock_this_device`, so they stop travelling in backups.
///
/// ## Why a migration at all
///
/// iOS cannot change an item's accessibility in place. `flutter_secure_storage`
/// 9.x reads an item whatever its accessibility, but a write with a different
/// one **deletes the item and adds it again**. An item is therefore only
/// re-protected when rewritten — and the database device key is never
/// rewritten outside a rotation, so without this it would keep the old,
/// backup-eligible protection forever.
///
/// ## Why it is crash-safe
///
/// That delete-then-add is not atomic. Losing the database device key in the
/// gap makes the encrypted database — and every unsynced visit, depot and
/// order in it — permanently unreadable. So each value is first copied to a
/// backup item, then rewritten, then read back and compared, and only then is
/// the backup removed. A run interrupted at any point is repaired by [run] on
/// the next launch: a backup whose original is missing is restored.
///
/// ## Failure behaviour
///
/// Never throws. A locked device or a Keychain error leaves everything as it
/// was and the migration tries again next launch. It is a no-op off iOS.
class KeychainAccessibilityMigration {
  const KeychainAccessibilityMigration({
    required FlutterSecureStorage storage,
    required bool isIos,
    AppLogger? logger,
    List<String> keys = SecureStorageKeys.all,
  })  : _storage = storage,
        _isIos = isIos,
        _logger = logger,
        _keys = keys;

  final FlutterSecureStorage _storage;
  final bool _isIos;
  final AppLogger? _logger;
  final List<String> _keys;

  /// Bump to re-run the migration after changing the accessibility again.
  static const int currentVersion = 1;

  static const String backupPrefix = 'isi.migrating.';

  Future<void> run() async {
    if (!_isIos) return;
    try {
      await _restoreInterrupted();

      final done = await _storage.read(
        key: SecureStorageKeys.kKeychainAccessibilityVersion,
      );
      if (done == '$currentVersion') return;

      var migrated = 0;
      for (final key in _keys) {
        if (await _migrate(key)) migrated++;
      }

      await _storage.write(
        key: SecureStorageKeys.kKeychainAccessibilityVersion,
        value: '$currentVersion',
      );
      _logger?.info('keychain.migration.done', fields: {'items': migrated});
    } catch (e) {
      // Only the key names are safe to log; values are secrets.
      _logger?.warning('keychain.migration.deferred', fields: {
        'cause': e.runtimeType.toString(),
      });
    }
  }

  /// Rewrites one item under the new protection. Returns whether it existed.
  Future<bool> _migrate(String key) async {
    final value = await _storage.read(key: key);
    if (value == null) return false;

    final backup = '$backupPrefix$key';
    await _storage.write(key: backup, value: value);
    await _storage.write(key: key, value: value);

    final check = await _storage.read(key: key);
    if (check != value) {
      // Leave the backup in place; the next run restores from it.
      throw StateError('Keychain rewrite of $key did not verify.');
    }
    await _storage.delete(key: backup);
    return true;
  }

  /// Puts back any original lost between delete and add on an earlier run.
  Future<void> _restoreInterrupted() async {
    for (final key in _keys) {
      final backup = '$backupPrefix$key';
      final saved = await _storage.read(key: backup);
      if (saved == null) continue;

      // A present original is either untouched or fully rewritten — both
      // hold the backed-up value. Only a missing one needs restoring.
      if (await _storage.read(key: key) == null) {
        await _storage.write(key: key, value: saved);
        // Keep the backup until the restore is proven.
        if (await _storage.read(key: key) != saved) continue;
        _logger?.warning('keychain.migration.restored', fields: {'key': key});
      }
      await _storage.delete(key: backup);
    }
  }
}
