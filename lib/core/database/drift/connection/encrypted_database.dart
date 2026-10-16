import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:steelforce/core/database/drift/connection/database_files.dart';
import 'package:steelforce/core/database/secure/app_database_key_provider.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';

/// Builds the encrypted [LazyDatabase] executor backing the single application
/// database. The connection is opened against SQLCipher (never plain SQLite),
/// keyed with the composite passphrase from [AppDatabaseKeyProvider]
/// (`SHA256(dbSalt + deviceKey)`), and refuses to open at all if encryption is
/// not active or the key is wrong.
///
/// ## One open path, non-destructive recovery
///
/// Earlier revisions probed the file with a throwaway connection and then let
/// drift's `NativeDatabase(setup: …)` open it a second time. That left a gap:
/// any divergence between the two opens (probe passes, real open throws
/// `SQLITE_NOTADB`) surfaced as a permanent, per-query
/// "file is not a database (code 26)" that the recovery logic never saw.
/// Now there is exactly **one** open: the raw connection is opened, keyed, and
/// verified here, then handed to drift via [NativeDatabase.opened] — so a
/// wrong-key file is always detected at the same place it is handled. An
/// unreadable file is moved aside and recorded, never deleted — see
/// [openWithRecovery].
///
/// Native half of the `database_connection.dart` seam. The web half
/// (`web_database.dart`) exposes this same symbol, which is what lets
/// `AppDatabase` stay platform-agnostic.
///
/// Kept as a thin alias over [openEncryptedDatabase] rather than a rename: the
/// original name states the security guarantee this file provides (ADR-008),
/// and that guarantee is the reason the file exists. `openAppDatabaseConnection`
/// is the *seam's* name; `openEncryptedDatabase` is the *behaviour's* name.
LazyDatabase openAppDatabaseConnection(AppDatabaseKeyProvider keyProvider) =>
    openEncryptedDatabase(keyProvider);

LazyDatabase openEncryptedDatabase(AppDatabaseKeyProvider keyProvider) {
  return LazyDatabase(() async {
    await _ensureSqlCipherLoaded();

    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, DatabaseFiles.encryptedDbFileName));
    final passphrase = await keyProvider.databasePassphrase();

    final raw = await openWithRecovery<Database>(
      file: file,
      passphrase: passphrase,
      open: _openAndVerify,
    );

    return NativeDatabase.opened(raw);
  });
}

/// Opens [file], applies the SQLCipher key, and runs both fail-closed checks.
/// Throws (closing the handle first) if encryption is not active or the key
/// does not decrypt the file.
Database _openAndVerify(File file, String passphrase) {
  final db = sqlite3.open(file.path);
  try {
    // Supply the passphrase as a raw key ("x'...'"): the value is already
    // 256 bits of CSPRNG output, so SQLCipher's PBKDF2 derivation is skipped.
    // Must run before any other statement touches the file.
    db.execute('PRAGMA key = "x\'$passphrase\'";');

    // Fail closed #1: if plain sqlite3 (no cipher) somehow loaded, this
    // pragma returns no rows — we must not silently write plaintext.
    final cipher = db.select('PRAGMA cipher_version;');
    if (cipher.isEmpty || (cipher.first.values.first as String).isEmpty) {
      throw StateError(
        'SQLCipher is not active — refusing to open an unencrypted database.',
      );
    }

    // Fail closed #2: touching sqlite_master forces SQLCipher to decrypt the
    // header now, so a wrong/rotated key throws here at open time rather than
    // on the first feature query.
    db.select('SELECT count(*) FROM sqlite_master;');
    return db;
  } catch (_) {
    db.dispose();
    rethrow;
  }
}

/// SQLite primary result codes that positively identify a file this key can
/// never read: `SQLITE_NOTADB` (26 — header does not decrypt, i.e. key
/// mismatch) and `SQLITE_CORRUPT` (11). Anything else — I/O error, locked,
/// full disk, missing cipher, an unknown exception — says nothing about the
/// file's contents and must fail closed without touching it.
const Set<int> _unreadableFileCodes = {26, 11};

/// SQLite files that make up one database. The WAL in particular holds
/// committed-but-uncheckpointed pages and must travel with the main file.
const List<String> _databaseFileSuffixes = ['', '-wal', '-shm', '-journal'];

/// Suffix of the append-only recovery log kept beside the database file.
const String databaseRecoveryLogSuffix = '.recovery.log';

/// Opens [file] via [open], recovering **non-destructively** from a file the
/// current key positively cannot read.
///
/// The dominant real-world cause of an unreadable file is a backup/restore or
/// reinstall that kept the encrypted file but lost the Keystore-sealed device
/// key (Keystore entries are never backed up), so a brand-new key meets an old
/// file. But the same symptom appears if the key store merely *failed to read*
/// and a fresh key was minted — in which case the old file is still
/// decryptable with the original key. The local DB also holds unsynced field
/// work (ADR-002, ADR-006). So the file is never deleted:
///
///  1. Only a positively identified unreadable file ([_unreadableFileCodes])
///     triggers recovery. Every other failure rethrows with the file intact.
///  2. The file and its sidecars are **renamed** to
///     `<name><suffix>.<UTC timestamp>.corrupt`, preserved for support-led
///     recovery.
///  3. The event is recorded: a PII-free warning log (result code and backup
///     name only — never the exception, whose `causingStatement` can carry the
///     `PRAGMA key` passphrase) and a line appended to
///     `<name>$databaseRecoveryLogSuffix`, which the app can read back via
///     [readDatabaseRecoveryEvents] to tell the rep.
///  4. A fresh file is opened. If *that* fails, something other than the file
///     is wrong; the error propagates and the backup stays where it is.
///
/// Exposed for tests; production goes through [openEncryptedDatabase].
@visibleForTesting
Future<T> openWithRecovery<T>({
  required File file,
  required String passphrase,
  required T Function(File file, String passphrase) open,
  DateTime Function() clock = _utcNow,
  AppLogger logger = const ConsoleAppLogger(),
}) async {
  try {
    return open(file, passphrase);
  } on SqliteException catch (e) {
    final code = e.resultCode;
    if (!_unreadableFileCodes.contains(code)) rethrow;
    if (!file.existsSync()) rethrow;

    final stamp = _timestamp(clock());
    final backup = _moveDatabaseFilesAside(file, stamp);
    final backupName = p.basename(backup.path);

    logger.warning(
      'db.encrypted.unreadable_file_moved_aside',
      fields: {'sqliteCode': code, 'backup': backupName},
    );
    try {
      _appendRecoveryEvent(
        file,
        DatabaseRecoveryEvent(
          occurredAt: clock(),
          sqliteResultCode: code,
          backupFileName: backupName,
        ),
      );
    } on FileSystemException {
      // The renamed backup on disk and the log line above remain as the
      // trace; failing to write the marker must not strand the rep with an
      // app that cannot open.
      logger.error(
        'db.encrypted.recovery_marker_write_failed',
        fields: {'backup': backupName},
      );
    }

    // Fresh file — this open creates it and must succeed; if it throws,
    // something other than the old file is wrong and we fail closed.
    return open(file, passphrase);
  }
}

/// One non-destructive recovery of an unreadable database file.
class DatabaseRecoveryEvent {
  const DatabaseRecoveryEvent({
    required this.occurredAt,
    required this.sqliteResultCode,
    required this.backupFileName,
  });

  final DateTime occurredAt;
  final int sqliteResultCode;

  /// Basename of the preserved main database file, e.g.
  /// `isi_secure.db.20260929T101500Z.corrupt`.
  final String backupFileName;

  Map<String, Object> toJson() => {
        'occurredAt': occurredAt.toUtc().toIso8601String(),
        'sqliteResultCode': sqliteResultCode,
        'backupFileName': backupFileName,
      };

  static DatabaseRecoveryEvent? tryParse(String line) {
    try {
      final map = jsonDecode(line) as Map<String, dynamic>;
      return DatabaseRecoveryEvent(
        occurredAt: DateTime.parse(map['occurredAt'] as String),
        sqliteResultCode: map['sqliteResultCode'] as int,
        backupFileName: map['backupFileName'] as String,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Every recovery recorded beside [databaseFile], oldest first. Empty when the
/// database has never been moved aside.
List<DatabaseRecoveryEvent> readDatabaseRecoveryEvents(File databaseFile) {
  final log = File('${databaseFile.path}$databaseRecoveryLogSuffix');
  if (!log.existsSync()) return const [];
  return log
      .readAsLinesSync()
      .map(DatabaseRecoveryEvent.tryParse)
      .whereType<DatabaseRecoveryEvent>()
      .toList(growable: false);
}

void _appendRecoveryEvent(File databaseFile, DatabaseRecoveryEvent event) {
  File('${databaseFile.path}$databaseRecoveryLogSuffix').writeAsStringSync(
    '${jsonEncode(event.toJson())}\n',
    mode: FileMode.append,
    flush: true,
  );
}

/// Renames the database file and every sidecar to a timestamped `.corrupt`
/// backup and returns the backup of the main file. Throws (leaving whatever
/// was not yet moved in place) if a rename fails — never deletes.
File _moveDatabaseFilesAside(File file, String stamp) {
  late File mainBackup;
  for (final suffix in _databaseFileSuffixes) {
    final source = File('${file.path}$suffix');
    final target = File('${file.path}$suffix.$stamp.corrupt');
    if (suffix.isEmpty) mainBackup = target;
    if (source.existsSync()) source.renameSync(target.path);
  }
  return mainBackup;
}

DateTime _utcNow() => DateTime.now().toUtc();

/// `20260929T101500Z` — sortable and filesystem-safe on every platform.
String _timestamp(DateTime t) {
  final u = t.toUtc();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${u.year.toString().padLeft(4, '0')}${two(u.month)}${two(u.day)}'
      'T${two(u.hour)}${two(u.minute)}${two(u.second)}Z';
}

/// Ensures the sqlite3 symbols resolve to the bundled SQLCipher build on every
/// supported platform. Idempotent — safe to call on each open.
Future<void> _ensureSqlCipherLoaded() async {
  // Some old Android versions need SQLCipher's libraries opened up front.
  await applyWorkaroundToOpenSqlCipherOnOldAndroidVersions();
  open.overrideFor(OperatingSystem.android, openCipherOnAndroid);

  // On iOS/macOS SQLCipher is statically linked into the process, so its
  // symbols are found via the running process image.
  if (Platform.isIOS) {
    open.overrideFor(OperatingSystem.iOS, DynamicLibrary.process);
  } else if (Platform.isMacOS) {
    open.overrideFor(OperatingSystem.macOS, DynamicLibrary.process);
  }
}
