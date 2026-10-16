import 'package:steelforce/features/my_visits/data/models/depot_stop_info_model.dart';
import 'package:steelforce/features/my_visits/data/models/route_plan_model.dart';

class RouteSyncPage {
  const RouteSyncPage({
    required this.depots,
    required this.routes,
    required this.hasMore,
    this.generatedAt,
    this.territories = const [],
  });

  final List<DepotStopInfoModel> depots;
  final List<RoutePlanModel> routes;
  final bool hasMore;

  /// The server's clock when the page was read (`data.generatedAt`), and the
  /// **only** valid source for the next delta's `since`.
  ///
  /// Never substitute the device clock. A handset running fast would ask for
  /// changes since the future — which the API now rejects with a 400 rather
  /// than answering with an empty page the client would store and then never
  /// sync from again (api.md §5.2).
  ///
  /// Nullable only so an older or mocked feed that omits it still parses; the
  /// live contract puts it on every response.
  final DateTime? generatedAt;

  /// The territories the server says are on this page.
  ///
  /// The client does not consume these — it is diagnostic. A pull that returns
  /// zero routes is ambiguous on its own: the rep may genuinely have no work,
  /// or the `territory` filter may not match anything the server holds. Logging
  /// what was asked for next to what came back separates those two in one line
  /// instead of a support round trip.
  final List<String> territories;
}
