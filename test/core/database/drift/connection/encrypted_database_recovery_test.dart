import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/database/drift/connection/encrypted_database.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

/// Captures log records so the test can assert what was (and was not) logged.
class _RecordingLogger implements AppLogger {
  final List<(String, Map<String, Object?>?)> records = [];

  @override
  void debug(String event, {Map<String, Object?>? fields}) =>
      records.add((event, fields));
  @override
  void info(String event, {Map<String, Object?>? fields}) =>
      records.add((event, fields));
  @override
  void warning(String event, {Map<String, Object?>? fields}) =>
      records.add((event, fields));
  @override
  void error(
    String event, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? fields,
  }) =>
      records.add((event, fields));
}

void main() {
  late Directory dir;
  late File db;
  late _RecordingLogger logger;
  final fixedNow = DateTime.utc(2026, 9, 29, 10, 15, 0);

  setUp(() {
    dir = Directory.systemTemp.createTempSync('enc_db_recovery_');
    db = File(p.join(dir.path, 'isi_secure.db'))
      ..writeAsStringSync('encrypted-main');
    File('${db.path}-wal').writeAsStringSync('encrypted-wal');
    logger = _RecordingLogger();
  });

  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  List<String> filesInDir() =>
      dir.listSync().map((e) => p.basename(e.path)).toList()..sort();

  /// Opener that throws [first] once, then "opens" (returns the file's state).
  String Function(File, String) failOnceWith(Object first) {
    var calls = 0;
    return (file, _) {
      calls++;
      if (calls == 1) throw first;
      return file.existsSync() ? 'opened:${file.readAsStringSync()}' : 'new';
    };
  }

  group('unknown / transient failures never touch the file', () {
    final cases = <String, Object>{
      'SQLITE_IOERR (10)': SqliteException(10, 'disk I/O error'),
      'SQLITE_BUSY (5)': SqliteException(5, 'database is locked'),
      'SQLITE_FULL (13)': SqliteException(13, 'database or disk is full'),
      'SQLITE_CANTOPEN (14)': SqliteException(14, 'unable to open'),
      'cipher missing (StateError)': StateError('SQLCipher is not active'),
      'arbitrary exception': Exception('boom'),
    };

    cases.forEach((name, error) {
      test(name, () async {
        await expectLater(
          openWithRecovery<String>(
            file: db,
            passphrase: 'k',
            open: failOnceWith(error),
            clock: () => fixedNow,
            logger: logger,
          ),
          throwsA(same(error)),
        );

        expect(db.readAsStringSync(), 'encrypted-main');
        expect(File('${db.path}-wal').readAsStringSync(), 'encrypted-wal');
        expect(filesInDir(), ['isi_secure.db', 'isi_secure.db-wal']);
        expect(readDatabaseRecoveryEvents(db), isEmpty);
        expect(logger.records, isEmpty);
      });
    });
  });

  group('a positively unreadable file is moved aside, not deleted', () {
    for (final code in [26, 11, 26 | (1 << 8)]) {
      test('result code $code', () async {
        final result = await openWithRecovery<String>(
          file: db,
          passphrase: 'k',
          open: failOnceWith(SqliteException(code, 'file is not a database')),
          clock: () => fixedNow,
          logger: logger,
        );

        expect(result, 'new', reason: 'the reopen starts a fresh file');

        const stamp = '20260929T101500Z';
        final backup = File('${db.path}.$stamp.corrupt');
        final walBackup = File('${db.path}-wal.$stamp.corrupt');
        expect(backup.readAsStringSync(), 'encrypted-main');
        expect(walBackup.readAsStringSync(), 'encrypted-wal');
        expect(db.existsSync(), isFalse);

        final events = readDatabaseRecoveryEvents(db);
        expect(events, hasLength(1));
        expect(events.single.backupFileName, p.basename(backup.path));
        expect(events.single.sqliteResultCode, code & 0xff);
        expect(events.single.occurredAt, fixedNow);

        expect(logger.records, hasLength(1));
        final (event, fields) = logger.records.single;
        expect(event, 'db.encrypted.unreadable_file_moved_aside');
        expect(fields!.keys, unorderedEquals(['sqliteCode', 'backup']));
      });
    }

    test('repeated recoveries keep every backup and every event', () async {
      await openWithRecovery<String>(
        file: db,
        passphrase: 'k',
        open: failOnceWith(SqliteException(26, 'notadb')),
        clock: () => fixedNow,
        logger: logger,
      );
      db.writeAsStringSync('second-main');
      await openWithRecovery<String>(
        file: db,
        passphrase: 'k',
        open: failOnceWith(SqliteException(26, 'notadb')),
        clock: () => fixedNow.add(const Duration(hours: 1)),
        logger: logger,
      );

      expect(
        File('${db.path}.20260929T101500Z.corrupt').readAsStringSync(),
        'encrypted-main',
      );
      expect(
        File('${db.path}.20260929T111500Z.corrupt').readAsStringSync(),
        'second-main',
      );
      expect(readDatabaseRecoveryEvents(db), hasLength(2));
    });

    test('a failed reopen propagates and keeps the backup', () async {
      final reopenError = SqliteException(10, 'disk I/O error');
      var calls = 0;
      await expectLater(
        openWithRecovery<String>(
          file: db,
          passphrase: 'k',
          open: (_, __) {
            calls++;
            throw calls == 1 ? SqliteException(26, 'notadb') : reopenError;
          },
          clock: () => fixedNow,
          logger: logger,
        ),
        throwsA(same(reopenError)),
      );
      expect(
        File('${db.path}.20260929T101500Z.corrupt').readAsStringSync(),
        'encrypted-main',
      );
      expect(readDatabaseRecoveryEvents(db), hasLength(1));
    });

    test('no file on disk: a 26 is rethrown, nothing recorded', () async {
      db.deleteSync();
      File('${db.path}-wal').deleteSync();
      final error = SqliteException(26, 'notadb');
      await expectLater(
        openWithRecovery<String>(
          file: db,
          passphrase: 'k',
          open: failOnceWith(error),
          clock: () => fixedNow,
          logger: logger,
        ),
        throwsA(same(error)),
      );
      expect(readDatabaseRecoveryEvents(db), isEmpty);
    });
  });

  test('a successful open does nothing else', () async {
    final result = await openWithRecovery<String>(
      file: db,
      passphrase: 'k',
      open: (f, _) => 'opened:${f.readAsStringSync()}',
      logger: logger,
    );
    expect(result, 'opened:encrypted-main');
    expect(filesInDir(), ['isi_secure.db', 'isi_secure.db-wal']);
    expect(logger.records, isEmpty);
  });

  test('malformed recovery-log lines are skipped, not fatal', () {
    File('${db.path}$databaseRecoveryLogSuffix')
        .writeAsStringSync('not json\n');
    expect(readDatabaseRecoveryEvents(db), isEmpty);
  });
}
