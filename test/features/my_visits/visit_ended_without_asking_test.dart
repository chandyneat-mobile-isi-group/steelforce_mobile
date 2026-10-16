import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/domain/entities/check_out_context.dart';
import 'package:steelforce/features/my_visits/domain/entities/check_out_outcome.dart';
import 'package:steelforce/features/my_visits/domain/entities/depot_stop_info.dart';
import 'package:steelforce/features/my_visits/domain/entities/no_order_reason.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_stop.dart';
import 'package:steelforce/features/my_visits/domain/entities/territory_type.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_status.dart';
import 'package:steelforce/features/my_visits/domain/usecases/get_check_out_context.dart';
import 'package:steelforce/features/my_visits/presentation/navigation/ask_how_visit_ended.dart';

class _Context implements GetCheckOutContext {
  _Context(this.visit);

  final CheckOutContext? visit;

  @override
  ResultFuture<CheckOutContext?> call(NoParams params) async => Success(visit);
}

final _stop = RouteStop(
  id: 's-1',
  routeId: 'r-1',
  depot: const DepotStopInfo(
    id: 'd-1',
    name: 'Sok Hardware',
    nameKh: 'ហាងសុខ',
    code: 'C-1',
    contact: 'Sok',
    phone: '012',
    address: 'St 1',
    territory: 'PP',
    territoryType: TerritoryType.urban,
    latitude: 11.5,
    longitude: 104.9,
  ),
  sequence: 1,
  plannedArrival: null,
  plannedDeparture: null,
  status: VisitStatus.checkedIn,
);

VisitOrderOption _order(String id) => VisitOrderOption(
      ref: VisitOrderRef(clientId: id),
      createdAt: DateTime(2026, 10, 14),
      itemCount: 1,
      total: 10,
    );

/// The demo's one-tap Complete Visit: no sheet, but an honest record —
/// the orders taken, or "other" with a note saying no reason was asked.
void main() {
  tearDown(() => GetIt.instance.reset());

  Future<CheckOutDecision> decide(CheckOutContext? visit) {
    GetIt.instance.registerSingleton<GetCheckOutContext>(_Context(visit));
    return visitEndedWithoutAsking();
  }

  test('with orders taken at the stop, checks out with all of them', () async {
    final decision = await decide(
        CheckOutContext(stop: _stop, orders: [_order('q1'), _order('q2')]));
    expect(decision.choice?.outcome, CheckOutOutcome.withOrder);
    expect(decision.choice?.orders.map((o) => o.clientId), ['q1', 'q2']);
  });

  test('without orders, checks out as "other" and says why', () async {
    final decision = await decide(CheckOutContext(stop: _stop));
    expect(decision.choice?.outcome, CheckOutOutcome.withoutOrder);
    expect(decision.choice?.noOrderReason, NoOrderReason.otherCode);
    expect(decision.choice?.noOrderNote, unaskedCheckOutNote);
  });

  test('with no visit to describe, completes with no choice', () async {
    final decision = await decide(null);
    expect(decision.choice, isNull);
  });
}
