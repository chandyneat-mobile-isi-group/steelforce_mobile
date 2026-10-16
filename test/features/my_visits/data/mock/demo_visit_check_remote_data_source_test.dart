import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/demo/demo_network.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/features/my_visits/data/mock/demo_visit_check_remote_data_source.dart';
import 'package:steelforce/features/my_visits/data/mock/demo_visit_ledger.dart';
import 'package:steelforce/features/my_visits/data/models/check_in_record_model.dart';
import 'package:steelforce/features/my_visits/data/models/check_out_record_model.dart';
import 'package:steelforce/features/my_visits/data/repositories/visit_repository_impl.dart';
import 'package:steelforce/features/my_visits/domain/entities/check_out_outcome.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_status.dart';

const _stop = '${kDemoStopIdPrefix}20261014-1';
final _at = DateTime.utc(2026, 10, 14, 2);

CheckInRecordModel _checkIn(String id, {String stopId = _stop}) =>
    CheckInRecordModel(
      id: id,
      stopId: stopId,
      timestamp: _at,
      latitude: 11.5449,
      longitude: 104.9214,
      accuracyMeters: 8,
      distanceFromDepotMeters: 0,
      isMocked: false,
    );

CheckOutRecordModel _checkOut(String id, {String checkInId = 'ci-1'}) =>
    CheckOutRecordModel(
      id: id,
      stopId: _stop,
      timestamp: _at.add(const Duration(minutes: 40)),
      latitude: 11.5449,
      longitude: 104.9214,
      durationMinutes: 40,
      visitSummary: '',
      checkInId: checkInId,
      outcome: CheckOutOutcome.withoutOrder,
      noOrderReason: 'priceTooHigh',
    );

Matcher _apiError(String code, int status) => throwsA(isA<ApiException>()
    .having((e) => e.code, 'code', code)
    .having((e) => e.statusCode, 'status', status));

void main() {
  late DemoNetwork network;
  late DemoVisitLedger ledger;
  late DemoVisitCheckRemoteDataSource source;

  setUp(() {
    network = DemoNetwork();
    ledger = DemoVisitLedger(clock: () => _at);
    source = DemoVisitCheckRemoteDataSource(network, ledger);
  });

  group('checkIn', () {
    test('answers the server visit, checked in', () async {
      final visit = await source.checkIn(_checkIn('ci-1'));

      expect(visit.visitId, 'ci-1');
      expect(visit.stopId, _stop);
      expect(visit.status, VisitStatus.checkedIn);
      expect(visit.checkedInAt, _at);
      expect(visit.flagged, isFalse);
      expect(ledger.hasVisit(_stop), isTrue);
    });

    test('the same id again is the same visit (safe after a timeout)',
        () async {
      await source.checkIn(_checkIn('ci-1'));
      final again = await source.checkIn(_checkIn('ci-1'));
      expect(again.visitId, 'ci-1');
    });

    test('another id on an open visit is a 409 carrying the server visit',
        () async {
      await source.checkIn(_checkIn('ci-1'));
      await expectLater(
        source.checkIn(_checkIn('ci-2')),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', VisitErrorCodes.alreadyCheckedIn)
            .having(
                (e) => e.error.details?['visitId'], 'details.visitId', 'ci-1')),
      );
    });

    test('a visited stop refuses a new check-in as already completed',
        () async {
      await source.checkIn(_checkIn('ci-1'));
      await source.checkOut(_checkOut('co-1'));
      await expectLater(source.checkIn(_checkIn('ci-2')),
          _apiError(VisitErrorCodes.alreadyCompleted, 409));
    });

    test('a stop the demo never issued is 404', () async {
      await expectLater(source.checkIn(_checkIn('ci-1', stopId: 'stop-x')),
          _apiError(VisitErrorCodes.stopNotFound, 404));
    });

    test('checking in elsewhere closes the open visit as inferred', () async {
      await source.checkIn(_checkIn('ci-1'));
      await source
          .checkIn(_checkIn('ci-2', stopId: '${kDemoStopIdPrefix}20261014-2'));
      expect(ledger.execution(_stop)?.status, 'checkedOut');
    });
  });

  group('checkOut', () {
    test('closes the visit', () async {
      await source.checkIn(_checkIn('ci-1'));
      final visit = await source.checkOut(_checkOut('co-1'));

      expect(visit.status, VisitStatus.checkedOut);
      expect(visit.checkedOutAt, _at.add(const Duration(minutes: 40)));
      expect(
          ledger.visitDto(_stop)['checkOut']['noOrderReason'], 'priceTooHigh');
    });

    test('a second check-out id is 409 already checked out', () async {
      await source.checkIn(_checkIn('ci-1'));
      await source.checkOut(_checkOut('co-1'));
      await expectLater(source.checkOut(_checkOut('co-2')),
          _apiError(VisitErrorCodes.alreadyCheckedOut, 409));
    });

    test('accepted before its check-in, and flagged as such', () async {
      final visit = await source.checkOut(_checkOut('co-1'));
      expect(visit.status, VisitStatus.checkedOut);
      expect(ledger.visitDto(_stop)['checkOut']['issues'],
          ['checkOutBeforeCheckIn']);
    });
  });

  test('reasons arrive sorted, in English and Khmer', () async {
    final reasons = await source.fetchCheckOutReasons();

    expect(reasons.map((r) => r.code), [
      'stockStillEnough',
      'ownerNotAvailable',
      'priceTooHigh',
      'orderedByPhone',
      'boughtFromCompetitor',
      'other',
    ]);
    expect(reasons.every((r) => r.nameEn.isNotEmpty && r.nameKm.isNotEmpty),
        isTrue);
    expect(reasons.last.requiresNote, isTrue);
    expect(reasons.first.name('km'), 'ហាងនៅមានស្តុកគ្រប់គ្រាន់');
  });

  test('offline, every call fails as a network error and records nothing',
      () async {
    network.setOnline(false);
    final isNetwork = _apiErrorCode(ApiErrorCodes.network);

    await expectLater(source.checkIn(_checkIn('ci-1')), isNetwork);
    await expectLater(source.checkOut(_checkOut('co-1')), isNetwork);
    await expectLater(source.fetchCheckOutReasons(), isNetwork);
    expect(ledger.hasVisit(_stop), isFalse);
  });
}

Matcher _apiErrorCode(String code) =>
    throwsA(isA<ApiException>().having((e) => e.code, 'code', code));
