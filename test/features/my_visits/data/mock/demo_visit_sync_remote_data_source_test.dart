import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/demo/demo_network.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/features/my_visits/data/mock/demo_visit_ledger.dart';
import 'package:steelforce/features/my_visits/data/mock/demo_visit_sync_remote_data_source.dart';
import 'package:steelforce/features/my_visits/data/models/check_in_record_model.dart';
import 'package:steelforce/features/my_visits/data/models/check_out_record_model.dart';
import 'package:steelforce/features/my_visits/data/models/visit_capture_models.dart';
import 'package:steelforce/features/my_visits/data/remote/visit_push_batch.dart';
import 'package:steelforce/features/my_visits/data/repositories/visit_repository_impl.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_note.dart';

const _stop = '${kDemoStopIdPrefix}20261014-1';
final _at = DateTime.utc(2026, 10, 14, 2);

CheckInRecordModel _checkIn(String id, String stopId) => CheckInRecordModel(
      id: id,
      stopId: stopId,
      timestamp: _at,
      latitude: 11.5449,
      longitude: 104.9214,
      accuracyMeters: 8,
      distanceFromDepotMeters: 0,
      isMocked: false,
    );

CheckOutRecordModel _checkOut(String id, String stopId) => CheckOutRecordModel(
      id: id,
      stopId: stopId,
      timestamp: _at.add(const Duration(minutes: 30)),
      latitude: 11.5449,
      longitude: 104.9214,
      durationMinutes: 30,
      visitSummary: 'Stock counted',
      checkInId: 'ci-1',
    );

VisitPushBatch _batch({
  List<CheckInRecordModel> checkIns = const [],
  List<CheckOutRecordModel> checkOuts = const [],
  List<VisitNoteModel> notes = const [],
  List<VisitPhotoModel> photos = const [],
}) =>
    VisitPushBatch(
      checkIns: checkIns,
      checkOuts: checkOuts,
      orderLines: const [],
      stockUpdates: const [],
      returns: const [],
      collections: const [],
      notes: notes,
      photos: photos,
    );

void main() {
  late DemoNetwork network;
  late DemoVisitLedger ledger;
  late DemoVisitSyncRemoteDataSource source;

  setUp(() {
    network = DemoNetwork();
    ledger = DemoVisitLedger(clock: () => _at);
    source = DemoVisitSyncRemoteDataSource(network, ledger);
  });

  test('acknowledges every row, photos included, and remembers the visit',
      () async {
    final result = await source.pushVisitData(_batch(
      checkIns: [_checkIn('ci-1', _stop)],
      checkOuts: [_checkOut('co-1', _stop)],
      notes: [
        VisitNoteModel(
          id: 'n-1',
          stopId: _stop,
          type: VisitNoteType.competitorActivity,
          text: 'Rival banner outside',
          createdAt: _at,
        ),
      ],
      photos: [
        VisitPhotoModel(
            id: 'p-1',
            stopId: _stop,
            url: '/tmp/p.jpg',
            caption: 'Shelf',
            takenAt: _at),
      ],
    ));

    expect(result.acceptedIds, ['ci-1', 'co-1', 'n-1', 'p-1']);
    expect(result.rejectedIds, isEmpty);
    expect(result.discardedIds, isEmpty);
    expect(result.syncedAt, _at);
    expect(ledger.execution(_stop)?.status, 'checkedOut');
    expect(ledger.pushedIds, containsAll(['ci-1', 'co-1', 'n-1', 'p-1']));
  });

  test('a replayed batch is accepted again without changing the visit',
      () async {
    final batch = _batch(checkIns: [_checkIn('ci-1', _stop)]);
    await source.pushVisitData(batch);
    final again = await source.pushVisitData(batch);

    expect(again.acceptedIds, ['ci-1']);
    expect(ledger.visitDto(_stop)['visitId'], 'ci-1');
  });

  test('a conflicting check-in is accepted and the server copy kept', () async {
    await source.pushVisitData(_batch(checkIns: [_checkIn('ci-1', _stop)]));
    final result =
        await source.pushVisitData(_batch(checkIns: [_checkIn('ci-2', _stop)]));

    expect(result.acceptedIds, ['ci-2']);
    expect(ledger.visitDto(_stop)['visitId'], 'ci-1');
  });

  test('rows for a stop the demo never issued are discarded', () async {
    final result = await source
        .pushVisitData(_batch(checkIns: [_checkIn('ci-x', 'stop-unknown')]));

    expect(result.acceptedIds, isEmpty);
    expect(result.discardedIds, ['ci-x']);
    expect(result.discardReasons, {'ci-x': VisitErrorCodes.stopNotFound});
  });

  test('offline, the push fails as a network error and records nothing',
      () async {
    network.setOnline(false);
    await expectLater(
      source.pushVisitData(_batch(checkIns: [_checkIn('ci-1', _stop)])),
      throwsA(isA<ApiException>()
          .having((e) => e.code, 'code', ApiErrorCodes.network)),
    );
    expect(ledger.hasVisit(_stop), isFalse);
    expect(ledger.pushedIds, isEmpty);
  });
}
