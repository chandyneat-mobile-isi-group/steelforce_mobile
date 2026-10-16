import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/domain/entities/check_out_context.dart';
import 'package:steelforce/features/my_visits/domain/entities/check_out_outcome.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_status.dart';
import 'package:steelforce/features/my_visits/domain/repositories/active_workflow_repository.dart';
import 'package:steelforce/features/my_visits/domain/repositories/route_repository.dart';
import 'package:steelforce/features/order/domain/entities/quotation_status.dart';
import 'package:steelforce/features/order/domain/repositories/quotation_repository.dart';

/// The visit about to be closed, for the check-out sheet — or null when there
/// is no checked-in stop to close.
///
/// Spans three repositories on purpose, like [GetResumableRoute]: the active
/// workflow names the stop, the route holds it, and the Order feature's
/// quotation repository (a domain interface — `architecture.md` §1) holds what
/// was ordered there.
class GetCheckOutContext extends UseCase<CheckOutContext?, NoParams> {
  const GetCheckOutContext(this._workflows, this._routes, this._quotations);

  final ActiveWorkflowRepository _workflows;
  final RouteRepository _routes;
  final QuotationRepository _quotations;

  @override
  ResultFuture<CheckOutContext?> call(NoParams params) async {
    final workflow = (await _workflows.getActiveWorkflow())
        .when(success: (w) => w, failure: (_) => null);
    final stopId = workflow?.currentStopId;
    if (workflow == null || stopId == null) return const Success(null);

    final route = (await _routes.getRoute(workflow.routeId))
        .when(success: (r) => r, failure: (_) => null);
    final stop = route?.stops.where((s) => s.id == stopId).firstOrNull;
    if (stop == null || stop.status != VisitStatus.checkedIn) {
      return const Success(null);
    }

    // Saved quotations for this shop since check-in. A bare builder draft is
    // not an order (README Q4), so only `saved` and `converted` are offered.
    final since = stop.actualArrival;
    final quotations = await _quotations.watchQuotations().first;
    final orders = [
      for (final q in quotations)
        if (q.depotId == stop.depot.id &&
            q.status != QuotationStatus.draft &&
            (since == null || !q.createdAt.isBefore(since)))
          VisitOrderOption(
            ref: VisitOrderRef(clientId: q.id, quotationId: q.remoteId),
            createdAt: q.createdAt,
            itemCount: q.lines.length,
            total: q.total,
          ),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Success(CheckOutContext(stop: stop, orders: orders));
  }
}
