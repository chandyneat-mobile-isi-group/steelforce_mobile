import 'package:flutter/material.dart';
import 'package:steelforce/features/my_visits/presentation/navigation/today_visit_rules.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/network/connectivity/network_info.dart';
import 'package:steelforce/features/depots/domain/entities/depot.dart';
import 'package:steelforce/features/depots/domain/entities/depot_list_kind.dart';
import 'package:steelforce/features/my_visits/domain/entities/ad_hoc_plan.dart';
import 'package:steelforce/features/my_visits/domain/usecases/start_ad_hoc_plan.dart';
import 'package:steelforce/features/my_visits/presentation/navigation/open_visit_plan.dart';

/// The outlet `POST /mobile/plans/ad-hoc` takes for this depot, or null when
/// an ad hoc visit cannot be started there.
///
/// A depot is sent by its code, a Non-BP depot by its id. One awaiting
/// approval is neither yet — the server answers `PLAN_OUTLET_NOT_FOUND` — so
/// every entry point hides the action for it.
extension DepotAdHocOutlet on Depot {
  AdHocPlanOutlet? get adHocOutlet {
    final code = depotCode.trim();
    final id = this.id.trim();
    return switch (depotType) {
      DepotTypes.depot when code.isNotEmpty => AdHocPlanOutlet.depot(code),
      DepotTypes.nonDepot when id.isNotEmpty => AdHocPlanOutlet.nonDepot(id),
      // A row cached before the list said its type: only an SAP depot.
      null when sapDepotId != null && code.isNotEmpty =>
        AdHocPlanOutlet.depot(code),
      _ => null,
    };
  }
}

/// Whether an ad hoc visit can be started right now — at [depot], when
/// given. Ad hoc visits are online only — the server decides the day, the
/// limit and whether the outlet is already visited — so offline the rep is
/// told at the tap, before the confirm dialog, rather than after filling it
/// in. So is a depot that already had its ad hoc visit today: one a day,
/// even once that visit is completed.
Future<bool> adHocVisitsAvailable(BuildContext context, {Depot? depot}) async {
  final messenger = ScaffoldMessenger.of(context);
  void say(String message) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
  if (!await sl<NetworkInfo>().isConnected) {
    say('my_visits.plans.ad_hoc.error.offline'.tr);
    return false;
  }
  final outlet = depot?.adHocOutlet;
  if (outlet != null && await adHocVisitToday(outlet) != null) {
    say('my_visits.ad_hoc.already_visited_today'
        .trParams({'name': depot!.shopName}));
    return false;
  }
  return true;
}

/// Starts an ad hoc visit for today at [depot] from **outside** the Visits
/// tab, and says what happened. Goes through the Visits feature's domain
/// usecase, never its data layer (`CLAUDE.md` §4).
///
/// Returns true when the depot is on today's visits as a result — including
/// "it already was", which is a success from the rep's point of view. A new
/// visit's SnackBar offers Start visit, which checks in to it like a plan.
Future<bool> startAdHocVisitAt(BuildContext context, Depot depot) async {
  final outlet = depot.adHocOutlet;
  if (outlet == null) return false;
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  final errorColor = Theme.of(context).colorScheme.error;
  final name = depot.shopName;

  final result = await sl<StartAdHocPlan>()(outlet);

  void say(String message, {bool isError = false, SnackBarAction? action}) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message, maxLines: 3, overflow: TextOverflow.ellipsis),
        backgroundColor: isError ? errorColor : null,
        action: action,
      ));
  }

  return result.when(
    success: (outcome) {
      switch (outcome) {
        case AdHocPlanStarted(:final plan):
          say(
            'my_visits.ad_hoc.added'.trParams({'name': name}),
            action: SnackBarAction(
              label: 'my_visits.plans.action.start_visit'.tr,
              onPressed: () {
                if (navigator.mounted) {
                  startVisitPlan(navigator.context, plan);
                }
              },
            ),
          );
        case AdHocPlanAlreadyToday():
          say('my_visits.ad_hoc.already_there'.trParams({'name': name}));
      }
      return true;
    },
    // The repository's message is a key; `.tr` passes a server-written
    // message through unchanged.
    failure: (failure) {
      say(
        failure is NetworkFailure
            ? 'my_visits.plans.ad_hoc.error.offline'.tr
            : failure.message.tr,
        isError: true,
      );
      return false;
    },
  );
}

/// A refusal as the rep reads it, with the support reference appended when
/// there is one.
///
/// `.tr` returns the key unchanged when it is not one, so a message the server
/// already localised passes straight through.
String adHocRefusalText(String message, String? supportReference) =>
    supportReference == null
        ? message.tr
        : '${message.tr}\n${'my_visits.ad_hoc.error.reference'.trParams({
                'id': supportReference
              })}';
