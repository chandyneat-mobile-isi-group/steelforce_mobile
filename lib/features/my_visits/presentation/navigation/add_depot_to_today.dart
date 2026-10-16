import 'package:flutter/material.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/features/depots/domain/entities/depot.dart';
import 'package:steelforce/features/my_visits/domain/entities/ad_hoc_visit_outcome.dart';
import 'package:steelforce/features/my_visits/domain/usecases/add_ad_hoc_visit.dart';

/// The code the ad hoc endpoint needs for this depot, or null when it cannot
/// be added at all.
///
/// The endpoint is keyed on the SAP code (`sk`, `ad-hoc-visits-mobile.md` §4).
/// A depot captured in the field has none until SAP reports it back, and no
/// value sent could find it — so every entry point disables the action rather
/// than letting the rep tap into a `Visit.DepotNotFound` for a shop in their
/// own list.
extension DepotAdHocVisitCode on Depot {
  String? get adHocVisitCode {
    final code = sapDepotId?.trim();
    return (code == null || code.isEmpty) ? null : code;
  }
}

/// Adds a depot to today's visits from **outside** the My Visits tab, and
/// reports what actually happened.
///
/// The Depots feature has its own entry points for this — the depot card and
/// the depot detail screen — and they cannot reach `AdHocVisitCubit`, which is
/// scoped to the My Visits tab. This helper is the seam, in the same shape as
/// `openQuotationForDepot`: a cross-feature action that goes through the other
/// feature's **domain** usecase, never its data layer (`CLAUDE.md` §4).
///
/// Returns true when the depot is on today's route as a result — including the
/// "it already was" case, which is a success from the rep's point of view.
Future<bool> addDepotToTodayVisits(
  BuildContext context, {
  required String depotId,
  required String sk,
  required String depotName,
}) async {
  final messenger = ScaffoldMessenger.of(context);

  final result = await sl<AddAdHocVisit>()(
    AddAdHocVisitParams(depotId: depotId, sk: sk, depotName: depotName),
  );

  void say(String message, {bool isError = false}) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message, maxLines: 3, overflow: TextOverflow.ellipsis),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      ));
  }

  return result.when(
    success: (outcome) {
      switch (outcome) {
        case AdHocVisitAdded():
          say('my_visits.ad_hoc.added'.trParams({'name': depotName}));
        case AdHocVisitAlreadyOnToday():
          // Not a failure. The depot is on their day either way.
          say('my_visits.ad_hoc.already_there'.trParams({'name': depotName}));
        case AdHocVisitQueued():
          // Deliberately phrased as a wait, not a success: nothing has been
          // added yet, and saying otherwise is what the old dialog did.
          say('my_visits.ad_hoc.queued'.trParams({'name': depotName}));
          return false;
      }
      return true;
    },
    failure: (failure) {
      // `.tr` returns the key unchanged when it is not one, so a message the
      // server already localised passes straight through.
      say(
        failure is AdHocVisitRefusedFailure
            ? adHocRefusalText(failure.message, failure.supportReference)
            : 'my_visits.ad_hoc.error.generic'.tr,
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
