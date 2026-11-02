// TODO(release-gate): demo-only data source; must never be registered in a release mobile build (USE_MOCK_DATA=false).
//
// [VisitCheckRemoteDataSource] for the static web demo: the route flow's
// online check-in / check-out and the "no order" reasons, answered from
// [MockVisitWorld] with no network call. A route stop's id is its plan's id,
// so a check-in here shows on the Plans list too.
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/core/utils/mock_latency.dart';
import 'package:steelforce/features/my_visits/data/models/check_in_record_model.dart';
import 'package:steelforce/features/my_visits/data/models/check_out_record_model.dart';
import 'package:steelforce/features/my_visits/data/remote/mock/mock_visit_world.dart';
import 'package:steelforce/features/my_visits/data/remote/visit_check_remote_data_source.dart';
import 'package:steelforce/features/my_visits/data/repositories/visit_repository_impl.dart';
import 'package:steelforce/features/my_visits/domain/entities/no_order_reason.dart';
import 'package:steelforce/features/my_visits/domain/entities/server_visit.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_plan.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_status.dart';

class MockVisitCheckRemoteDataSource implements VisitCheckRemoteDataSource {
  const MockVisitCheckRemoteDataSource(this._world);

  final MockVisitWorld _world;

  @override
  Future<ServerVisit> checkIn(CheckInRecordModel record) async {
    await MockLatency.tick();
    final visit = _stop(record.stopId)..checkIn(record.id, record.timestamp);
    return _serverVisit(visit);
  }

  @override
  Future<ServerVisit> checkOut(CheckOutRecordModel record) async {
    await MockLatency.tick();
    final visit = _stop(record.stopId)..checkOut(record.timestamp);
    return _serverVisit(visit);
  }

  @override
  Future<List<NoOrderReason>> fetchCheckOutReasons() async {
    await MockLatency.tick();
    return mockNoOrderReasons;
  }

  MockVisitRecord _stop(String stopId) =>
      _world.find(stopId) ??
      (throw const ApiException(ApiError(
        code: VisitErrorCodes.stopNotFound,
        statusCode: 404,
        message: 'This stop is not on your routes.',
      )));

  static ServerVisit _serverVisit(MockVisitRecord visit) => ServerVisit(
        visitId: visit.checkInId,
        stopId: visit.id,
        status: switch (visit.status) {
          VisitPlanStatus.checkedIn => VisitStatus.checkedIn,
          VisitPlanStatus.completed => VisitStatus.checkedOut,
          VisitPlanStatus.missed => VisitStatus.missed,
          _ => VisitStatus.pending,
        },
        checkedInAt: visit.checkedInAt,
        checkedOutAt: visit.checkedOutAt,
      );
}

/// The `GET /visits/check-out-reasons` list, as the server sends it: master
/// data in both languages, not app copy.
const List<NoOrderReason> mockNoOrderReasons = [
  NoOrderReason(
      code: 'stockStillEnough',
      nameEn: 'Shop still has enough stock',
      nameKm: 'ហាងនៅមានស្តុកគ្រប់គ្រាន់',
      requiresNote: false,
      sort: 1),
  NoOrderReason(
      code: 'ownerNotAvailable',
      nameEn: 'Owner / buyer not available',
      nameKm: 'ម្ចាស់ហាង ឬអ្នកទិញមិននៅ',
      requiresNote: false,
      sort: 2),
  NoOrderReason(
      code: 'priceTooHigh',
      nameEn: 'Price too high',
      nameKm: 'តម្លៃខ្ពស់ពេក',
      requiresNote: false,
      sort: 3),
  NoOrderReason(
      code: 'orderedByPhone',
      nameEn: 'Will order by phone later',
      nameKm: 'នឹងបញ្ជាទិញតាមទូរសព្ទពេលក្រោយ',
      requiresNote: false,
      sort: 4),
  NoOrderReason(
      code: 'boughtFromCompetitor',
      nameEn: 'Bought from a competitor',
      nameKm: 'បានទិញពីដៃគូប្រកួតប្រជែង',
      requiresNote: true,
      sort: 5),
  NoOrderReason.other,
];
