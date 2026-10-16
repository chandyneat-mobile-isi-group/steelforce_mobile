import 'package:flutter/material.dart';
import 'package:steelforce/core/config/feature_flags.dart';
import 'package:steelforce/core/animations/page_transition.dart';
import 'package:steelforce/core/localization/localized_builder.dart';
import 'package:steelforce/features/depots/presentation/screens/depot_detail_screen.dart';
import 'package:steelforce/features/my_visits/domain/entities/active_workflow.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_plan.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_workflow.dart';
import 'package:steelforce/features/my_visits/presentation/navigation/open_inventory_survey.dart';
import 'package:steelforce/features/my_visits/presentation/navigation/open_inventory_visibility.dart';
import 'package:steelforce/features/my_visits/presentation/navigation/open_quotation.dart';
import 'package:steelforce/features/my_visits/presentation/navigation/open_stop_information.dart';
import 'package:steelforce/features/my_visits/presentation/screens/inventory_visible/inventory_completion_screen.dart';
import 'package:steelforce/features/my_visits/presentation/screens/inventory_visible/inventory_visible_screen.dart';
import 'package:steelforce/features/my_visits/presentation/screens/stop_information/stop_information_screen.dart';
import 'package:steelforce/features/order/presentation/screens/quotation/quotation_builder_screen.dart';
import 'package:steelforce/features/order/presentation/screens/shop/shop_list_screen.dart';

/// Rebuilds a live screen from the args the workflow recorded. Returns `null`
/// when the required args are missing/invalid, so the dispatcher falls back to
/// guided stop resume.
typedef ResumeBuilder = Future<void>? Function(
    BuildContext context, RoutePlan route, ActiveWorkflow workflow);

/// The **single** registry mapping a persisted screen key (`routeName`) → how to
/// resume it.
final Map<String, ResumeBuilder> _navigationRegistry = {
  // Stop Information step — resume straight into stop review using stop context.
  StopInformationScreen.routeName: (context, route, w) {
    final stopId = w.navigationArguments?['stopId'] as String?;
    if (stopId == null) return null;

    final index = route.stops.indexWhere((s) => s.id == stopId);
    if (index == -1) return null;

    return openStopInformation(
      context,
      stop: route.stops[index],
      index: index,
      totalStops: route.stops.length,
    );
  },

  // Stock count task — resume straight into the Inventory Visibility step for
  // the checked-in depot. The baseline pointer `_writeWorkflowPointer`
  // writes at check-in, before the rep advances into a business task.
  InventoryVisibilityScreen.routeName: (context, route, w) {
    final depotId = w.navigationArguments?['depotId'] as String?;
    if (depotId == null) return null;
    final depotName =
        w.navigationArguments?['depotName'] as String? ?? w.shopName ?? '';
    final stopId =
        w.navigationArguments?['stopId'] as String? ?? w.currentStopId;
    return openInventoryStep(
      context,
      depotId: depotId,
      depotName: depotName,
      stopId: stopId,
    );
  },

  // Stock count finished — resume onto the "what next" decision rather than
  // back into the audit. The rep already walked the racks; sending them there
  // again is how a resume feature teaches people not to trust it.
  InventoryCompletionScreen.routeName: (context, route, w) {
    final depotId = w.navigationArguments?['depotId'] as String?;
    if (depotId == null) return null;
    final depotName =
        w.navigationArguments?['depotName'] as String? ?? w.shopName ?? '';
    final stopId =
        w.navigationArguments?['stopId'] as String? ?? w.currentStopId;
    return openInventoryCompletion(
      context,
      depotId: depotId,
      depotName: depotName,
      stopId: stopId,
    );
  },

  // Quotation task — resume straight into the Quotation Builder for the checked-in depot.
  QuotationBuilderScreen.routeName: (context, route, w) {
    // Switched off: fall back to resuming the stop itself.
    if (!FeatureFlags.quotesAndOrders) return null;
    final depotId = w.navigationArguments?['depotId'] as String?;
    if (depotId == null) return null;
    final depotName =
        w.navigationArguments?['depotName'] as String? ?? w.shopName ?? '';
    return openQuotationForDepot(
      context,
      depotId: depotId,
      depotName: depotName,
    );
  },

  // Legacy order handoff — re-enter the shop list for the visit's territory.
  ShopListScreen.routeName: (context, route, w) {
    if (!FeatureFlags.quotesAndOrders) return null;
    final territory = w.navigationArguments?['territory'] as String?;
    if (territory == null) return null;
    return _push(
      context,
      ShopListScreen.routeName,
      ShopListScreen(territory: territory, skipOffVisitCheck: true),
    );
  },

  // Depot profile.
  DepotDetailScreen.routeName: (context, route, w) {
    final depotId = w.navigationArguments?['depotId'] as String?;
    if (depotId == null) return null;
    return _push(
      context,
      DepotDetailScreen.routeName,
      DepotDetailScreen(depotId: depotId),
    );
  },
};

/// The canonical screen a coarse [VisitWorkflow] resumes to when no explicit
/// `currentScreen` was recorded.
String? _screenForWorkflow(VisitWorkflow? workflow) => switch (workflow) {
      VisitWorkflow.quotation ||
      VisitWorkflow.salesOrder =>
        ShopListScreen.routeName,
      _ => null,
    };

/// Pure stop-centric entry point to resume workflow directly into stop contexts.
Future<void> resumeActiveWorkflow(
  BuildContext context,
  RoutePlan route,
  ActiveWorkflow? workflow,
) {
  final key =
      workflow?.currentScreen ?? _screenForWorkflow(workflow?.currentWorkflow);
  final builder = key == null ? null : _navigationRegistry[key];

  if (builder != null && workflow != null) {
    final result = builder(context, route, workflow);
    if (result != null) return result;
  }

  // Primary Fallback: Safely extract stopId from navigationArguments map
  final activeStopId = workflow?.navigationArguments?['stopId'] as String?;
  if (activeStopId != null) {
    final stopIndex = route.stops.indexWhere((s) => s.id == activeStopId);
    if (stopIndex != -1) {
      return openStopInformation(
        context,
        stop: route.stops[stopIndex],
        index: stopIndex,
        totalStops: route.stops.length,
      );
    }
  }

  // Secondary Fallback: Default straight to the first stop in the list
  if (route.stops.isNotEmpty) {
    return openStopInformation(
      context,
      stop: route.stops.first,
      index: 0,
      totalStops: route.stops.length,
    );
  }

  return Future.value();
}

Future<void> _push(BuildContext context, String routeName, Widget screen) {
  return Navigator.of(context).push(AppPageRoute<void>.fadeThrough(
    settings: RouteSettings(name: routeName),
    builder: (_) => LocalizedBuilder(builder: (_) => screen),
  ));
}
