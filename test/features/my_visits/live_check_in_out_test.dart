import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/core/network/connectivity/network_info.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/features/my_visits/data/local/visit_drift_local_data_source.dart';
import 'package:steelforce/features/my_visits/data/models/check_in_record_model.dart';
import 'package:steelforce/features/my_visits/data/models/check_out_record_model.dart';
import 'package:steelforce/features/my_visits/data/models/visit_api_mapper.dart';
import 'package:steelforce/features/my_visits/data/remote/visit_check_remote_data_source.dart';
import 'package:steelforce/features/my_visits/data/repositories/visit_repository_impl.dart';
import 'package:steelforce/features/my_visits/domain/entities/check_in_record.dart';
import 'package:steelforce/features/my_visits/domain/entities/check_out_outcome.dart';
import 'package:steelforce/features/my_visits/domain/entities/check_out_record.dart';
import 'package:steelforce/features/my_visits/domain/entities/no_order_reason.dart';
import 'package:steelforce/features/my_visits/domain/entities/server_visit.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_send_result.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_status.dart';

/// Online check-in / check-out (`check-in-check-out-mobile.md` §4, §5, §10):
/// saved on the phone first, then offered to the server. Anything short of a
/// definite answer stays queued for the batch push.
class _Network implements NetworkInfo {
  bool online = true;
  @override
  Future<bool> get isConnected async => online;
}

class _Remote implements VisitCheckRemoteDataSource {
  final List<String> calls = [];
  Object? checkInAnswer;
  Object? checkOutAnswer;

  @override
  Future<ServerVisit> checkIn(CheckInRecordModel record) =>
      _answer('checkIn:${record.id}', checkInAnswer, record.stopId);

  @override
  Future<ServerVisit> checkOut(CheckOutRecordModel record) =>
      _answer('checkOut:${record.id}', checkOutAnswer, record.stopId);

  @override
  Future<List<NoOrderReason>> fetchCheckOutReasons() async => const [];

  Future<ServerVisit> _answer(String call, Object? answer, String stopId) {
    calls.add(call);
    if (answer is Exception) return Future.error(answer);
    if (answer is Completer<ServerVisit>) return answer.future;
    return Future.value(ServerVisit(
        stopId: stopId, status: VisitStatus.checkedIn, visitId: 'srv'));
  }
}

ApiException _api(int status, String code, {Map<String, dynamic>? details}) =>
    ApiException(ApiError(code: code, statusCode: status, details: details));

void main() {
  late AppDatabase db;
  late VisitDriftLocalDataSource local;
  late _Network network;
  late _Remote remote;
  late VisitRepositoryImpl visits;
  late int queuedWakes;

  final at = DateTime.utc(2026, 10, 5, 2);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    local = VisitDriftLocalDataSource(
        db.visitDao, const ConsoleAppLogger(verbose: false));
    network = _Network();
    remote = _Remote();
    queuedWakes = 0;
    visits = VisitRepositoryImpl(
      local,
      remote: remote,
      network: network,
      onQueued: () => queuedWakes++,
      onlineWait: const Duration(milliseconds: 100),
    );
  });

  tearDown(() => db.close());

  CheckInRecord checkIn({String id = 'ci-1', String stopId = 's-1'}) =>
      CheckInRecord(
        id: id,
        stopId: stopId,
        timestamp: at,
        latitude: 11.55,
        longitude: 104.91,
        accuracyMeters: 8,
        distanceFromDepotMeters: 20,
        isMocked: false,
        routeId: 'r-1',
      );

  CheckOutRecord checkOut({String? checkInId = 'ci-1'}) => CheckOutRecord(
        id: 'co-1',
        stopId: 's-1',
        timestamp: at.add(const Duration(minutes: 40)),
        latitude: 11.55,
        longitude: 104.91,
        durationMinutes: 40,
        visitSummary: 'Visit completed',
        checkInId: checkInId,
        outcome: CheckOutOutcome.withoutOrder,
        noOrderReason: 'priceTooHigh',
      );

  Future<VisitSendStatus> sendIn(CheckInRecord r) async {
    await visits.checkIn(r);
    return (await visits.sendCheckIn(r) as Success<VisitSendResult>)
        .data
        .status;
  }

  Future<VisitSendStatus> sendOut(CheckOutRecord r) async {
    await visits.checkOut(r);
    return (await visits.sendCheckOut(r) as Success<VisitSendResult>)
        .data
        .status;
  }

  group('check-in', () {
    test('online: the server takes it and nothing is left to push', () async {
      expect(await sendIn(checkIn()), VisitSendStatus.sent);
      expect(remote.calls, ['checkIn:ci-1']);
      expect(await local.countPendingCheckIns(), 0);
      expect(queuedWakes, 0, reason: 'nothing for the sync engine to do');
    });

    test('offline: saved on the phone, queued, no request', () async {
      network.online = false;
      expect(await sendIn(checkIn()), VisitSendStatus.queued);
      expect(remote.calls, isEmpty);
      expect(await local.countPendingCheckIns(), 1);
      expect(queuedWakes, 1);
    });

    test('a slow server: the rep moves on, the row stays queued', () async {
      remote.checkInAnswer = Completer<ServerVisit>();
      expect(await sendIn(checkIn()), VisitSendStatus.queued);
      expect(await local.countPendingCheckIns(), 1);
      expect(queuedWakes, 1);
    });

    test('a server error queues it for the lenient batch push', () async {
      remote.checkInAnswer = _api(500, 'General.Unexpected');
      expect(await sendIn(checkIn()), VisitSendStatus.queued);
      expect(await local.countPendingCheckIns(), 1);
    });

    test('409 AlreadyCheckedIn: adopts the server visit id', () async {
      remote.checkInAnswer = _api(409, 'Visit.AlreadyCheckedIn', details: {
        'visitId': 'srv-visit',
        'stopId': 's-1',
        'status': 'checkedIn'
      });
      expect(await sendIn(checkIn()), VisitSendStatus.sent);

      final row = await local.checkInForStop('s-1');
      expect(row!.id, 'srv-visit', reason: 'the check-out must close this one');
      expect(await local.countPendingCheckIns(), 0);
    });

    test('409 AlreadyCompleted: refused, and the row is dropped', () async {
      remote.checkInAnswer = _api(409, 'Visit.AlreadyCompleted',
          details: {'visitId': 'old', 'stopId': 's-1', 'status': 'checkedOut'});
      expect(await sendIn(checkIn()), VisitSendStatus.alreadyVisited);
      expect(await local.checkInForStop('s-1'), isNull);
      expect(await local.countPendingVisitRecords(), 0);
    });

    test('404 StopNotFound: refused, and the row is dropped', () async {
      remote.checkInAnswer = _api(404, 'Visit.StopNotFound');
      expect(await sendIn(checkIn()), VisitSendStatus.notOnRoute);
      expect(await local.checkInForStop('s-1'), isNull);
    });
  });

  group('check-out', () {
    test('online, after its check-in landed: sent', () async {
      await sendIn(checkIn());
      expect(await sendOut(checkOut()), VisitSendStatus.sent);
      expect(remote.calls, ['checkIn:ci-1', 'checkOut:co-1']);
      expect(await local.countPendingVisitRecords(), 0);
    });

    test('held while its check-in is still on the phone', () async {
      network.online = false;
      await sendIn(checkIn());
      network.online = true;

      expect(await sendOut(checkOut()), VisitSendStatus.queued);
      expect(remote.calls, isEmpty,
          reason: 'a check-out never reaches the server before its check-in');
      expect(await local.countPendingVisitRecords(), 2);
    });

    test('a check-out follows the adopted visit id', () async {
      network.online = false;
      await sendIn(checkIn());
      await visits.checkOut(checkOut());
      // Later, online, the server says another device opened this visit.
      await local.adoptServerCheckIn('ci-1', 'srv-visit');

      final saved = (await local.fetchPendingCheckOuts()).single;
      expect(saved.checkInId, 'srv-visit');
    });

    test('409 AlreadyCheckedOut: the server visit stands; nothing to push',
        () async {
      await sendIn(checkIn());
      remote.checkOutAnswer = _api(409, 'Visit.AlreadyCheckedOut');
      expect(await sendOut(checkOut()), VisitSendStatus.sent);
      expect(await local.countPendingCheckOuts(), 0);
    });

    test('the outcome survives the database round trip', () async {
      network.online = false;
      await visits.checkOut(CheckOutRecord(
        id: 'co-2',
        stopId: 's-2',
        timestamp: at,
        latitude: 1,
        longitude: 2,
        durationMinutes: 5,
        visitSummary: 'Visit completed',
        checkInId: 'ci-2',
        outcome: CheckOutOutcome.withOrder,
        orders: const [
          VisitOrderRef(clientId: 'qt-1', quotationId: 'srv-q1'),
          VisitOrderRef(clientId: 'qt-2'),
        ],
      ));
      final row = (await local.fetchPendingCheckOuts()).single;
      expect(row.outcome, CheckOutOutcome.withOrder);
      expect(row.orders.map((o) => o.clientId), ['qt-1', 'qt-2']);
      expect(row.orders.first.quotationId, 'srv-q1');
      expect(row.checkInId, 'ci-2');
    });
  });

  group('wire format (same body online and in /push)', () {
    CheckOutRecordModel model(CheckOutRecord r) =>
        CheckOutRecordModel.fromEntity(r);

    test('without order: reason, and a note only when there is one', () {
      final json = model(checkOut()).toApiJson();
      expect(json['checkInId'], 'ci-1');
      expect(json['outcome'], 'withoutOrder');
      expect(json['noOrderReason'], 'priceTooHigh');
      expect(json.containsKey('noOrderNote'), isFalse);
      expect(json.containsKey('orders'), isFalse);
    });

    test('with order: the orders, with a null server id when not synced', () {
      final json = model(CheckOutRecord(
        id: 'co-1',
        stopId: 's-1',
        timestamp: at,
        latitude: 1,
        longitude: 2,
        durationMinutes: 5,
        visitSummary: 'Visit completed',
        outcome: CheckOutOutcome.withOrder,
        orders: const [VisitOrderRef(clientId: 'qt-1')],
      )).toApiJson();
      expect(json['orders'], [
        {'clientId': 'qt-1', 'quotationId': null, 'type': 'quotation'}
      ]);
      expect(json.containsKey('noOrderReason'), isFalse);
      expect(json.containsKey('checkInId'), isFalse);
    });

    test('a check-out saved before outcomes existed is sent as it was', () {
      final json = model(CheckOutRecord(
        id: 'co-1',
        stopId: 's-1',
        timestamp: at,
        latitude: 1,
        longitude: 2,
        durationMinutes: 5,
        visitSummary: 'Visit completed',
      )).toApiJson();
      expect(json.keys, isNot(contains('outcome')));
    });

    test('the check-in carries its route', () {
      expect(CheckInRecordModel.fromEntity(checkIn()).toApiJson()['routeId'],
          'r-1');
    });
  });

  test('a 409 problem document keeps its details for adoption', () {
    final error = ApiError.fromBody({
      'status': 409,
      'errorCode': 'Visit.AlreadyCheckedIn',
      'details': {'visitId': 'srv-visit', 'stopId': 's-1'},
    });
    expect(error.code, 'Visit.AlreadyCheckedIn');
    expect(error.details?['visitId'], 'srv-visit');
  });
}
