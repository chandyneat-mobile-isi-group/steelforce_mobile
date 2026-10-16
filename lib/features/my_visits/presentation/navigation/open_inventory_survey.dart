import 'package:flutter/material.dart';
import 'package:steelforce/core/animations/page_transition.dart';
import 'package:steelforce/core/camera/image_capture_service.dart';
import 'package:steelforce/core/config/data_source_mode.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/localization/localized_builder.dart';
import 'package:steelforce/features/my_visits/presentation/navigation/open_inventory_visibility.dart';
import 'package:steelforce/features/my_visits/presentation/screens/inventory_visible/inventory_survey_screen.dart';

/// Opens the stock step of a checked-in visit.
///
/// Demo builds ask for three photos (the Inventory Availability Survey);
/// live builds keep the single stock photo until the business confirms the
/// change. Both save to the visit and end on the same completion screen.
///
/// TODO(release-gate): decide whether live builds move to three photos,
/// then remove this switch.
Future<void> openInventoryStep(
  BuildContext context, {
  required String depotId,
  required String depotName,
  String? stopId,
}) {
  if (DataSourceMode.useLiveApi) {
    return openInventoryVisibilityForDepot(context,
        depotId: depotId, depotName: depotName, stopId: stopId);
  }
  return openInventorySurveyForDepot(context,
      depotId: depotId, depotName: depotName, stopId: stopId);
}

/// Three photos → Submit → the "Inventory photo submitted" screen.
///
/// Each photo is saved exactly as the single stock photo is: to local visit
/// storage, syncing with the stop's next visit push.
Future<void> openInventorySurveyForDepot(
  BuildContext context, {
  required String depotId,
  required String depotName,
  String? stopId,
}) {
  return Navigator.of(context).push(AppPageRoute<void>.sharedAxisVertical(
    settings: const RouteSettings(name: InventorySurveyScreen.routeName),
    builder: (routeContext) => LocalizedBuilder(
      builder: (_) => InventorySurveyScreen(
        depotName: depotName,
        capture: sl<ImageCaptureService>(),
        onPhotosSubmitted: (shots) async {
          for (final shot in shots) {
            await saveInventoryPhoto(
              depotId: depotId,
              stopId: stopId,
              photo: shot.file,
              takenAt: shot.takenAt,
            );
          }
        },
        onSubmit: () => continueToInventoryCompletion(
          routeContext,
          depotId: depotId,
          depotName: depotName,
          stopId: stopId,
        ),
      ),
    ),
  ));
}
