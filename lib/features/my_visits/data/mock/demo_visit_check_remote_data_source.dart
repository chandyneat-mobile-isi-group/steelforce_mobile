/// TODO(release-gate): demo-only, selected only when DataSourceMode.useMocks.
///
/// [VisitCheckRemoteDataSource] for a demo build: the online check-in /
/// check-out and the "no order" reasons, answered from [DemoVisitLedger].
///
/// Strict like the real endpoints: a second check-in under another id, or a
/// check-out of a closed visit, fails with the documented 409 and the
/// server's `VisitDto` in `details`, so `VisitRepositoryImpl`'s adopt paths
/// run exactly as they would live.
library;

import 'package:steelforce/core/demo/demo_network.dart';
import 'package:steelforce/features/my_visits/data/mock/demo_check_out_reason_fixtures.dart';
import 'package:steelforce/features/my_visits/data/mock/demo_visit_ledger.dart';
import 'package:steelforce/features/my_visits/data/models/check_in_record_model.dart';
import 'package:steelforce/features/my_visits/data/models/check_out_record_model.dart';
import 'package:steelforce/features/my_visits/data/models/visit_check_models.dart';
import 'package:steelforce/features/my_visits/data/remote/visit_check_remote_data_source.dart';
import 'package:steelforce/features/my_visits/domain/entities/no_order_reason.dart';
import 'package:steelforce/features/my_visits/domain/entities/server_visit.dart';

class DemoVisitCheckRemoteDataSource implements VisitCheckRemoteDataSource {
  const DemoVisitCheckRemoteDataSource(this._network, this._ledger);

  final DemoNetwork _network;
  final DemoVisitLedger _ledger;

  @override
  Future<ServerVisit> checkIn(CheckInRecordModel record) async {
    await _network.roundTrip();
    return serverVisitFromJson(_ledger.checkIn(
      id: record.id,
      stopId: record.stopId,
      timestamp: record.timestamp,
      overrideReason: record.overrideReason,
      isMocked: record.isMocked,
    ));
  }

  @override
  Future<ServerVisit> checkOut(CheckOutRecordModel record) async {
    await _network.roundTrip();
    return serverVisitFromJson(_ledger.checkOut(
      id: record.id,
      stopId: record.stopId,
      timestamp: record.timestamp,
      durationMinutes: record.durationMinutes,
      checkInId: record.checkInId,
      outcome: record.outcome?.name,
      noOrderReason: record.noOrderReason,
    ));
  }

  @override
  Future<List<NoOrderReason>> fetchCheckOutReasons() async {
    await _network.roundTrip();
    return demoCheckOutReasonsJson
        .map(noOrderReasonFromJson)
        .whereType<NoOrderReason>()
        .toList()
      ..sort((a, b) => a.sort.compareTo(b.sort));
  }
}
