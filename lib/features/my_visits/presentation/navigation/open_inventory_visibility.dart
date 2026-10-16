import 'dart:async';
import 'package:steelforce/core/config/feature_flags.dart';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:steelforce/core/camera/image_capture_service.dart';
import 'package:steelforce/core/animations/page_transition.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/localization/localized_builder.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/platform/storage/captured_media_store.dart';
import 'package:steelforce/core/usecase/usecase.dart' show NoParams;
import 'package:steelforce/features/my_visits/domain/entities/visit_photo.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_workflow.dart';
import 'package:steelforce/features/my_visits/domain/usecases/add_visit_photo.dart';
import 'package:steelforce/features/my_visits/domain/usecases/get_active_workflow.dart';
import 'package:steelforce/features/my_visits/domain/usecases/update_workflow_step.dart';
import 'package:steelforce/features/my_visits/presentation/navigation/end_visit.dart';
import 'package:steelforce/features/my_visits/presentation/navigation/open_quotation.dart';
import 'package:steelforce/features/my_visits/presentation/screens/inventory_visible/inventory_completion_screen.dart';
import 'package:steelforce/features/my_visits/presentation/screens/inventory_visible/inventory_visible_screen.dart';

/// Opens the guided Inventory Visibility step (one stock photo) for the
/// checked-in depot — the task that now sits between check-in and the
/// Quotation Builder.
///
/// The single construction path for "audit stock at this shop", so the
/// live check-in flow and the "Continue Working" resume land on the
/// identical screen with identical follow-on actions, exactly like
/// [openQuotationForDepot] does for the quotation step.
Future<void> openInventoryVisibilityForDepot(
  BuildContext context, {
  required String depotId,
  required String depotName,
  String? stopId,
}) async {
  await Navigator.of(context).push(AppPageRoute<void>.sharedAxisVertical(
    settings: const RouteSettings(name: InventoryVisibilityScreen.routeName),
    builder: (routeContext) => LocalizedBuilder(
      builder: (_) => InventoryVisibilityScreen(
        depotName: depotName,
        capture: sl<ImageCaptureService>(),
        onPhotoSubmitted: (photo, takenAt) => saveInventoryPhoto(
          depotId: depotId,
          stopId: stopId,
          photo: photo,
          takenAt: takenAt,
        ),
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

/// Caption that marks a visit photo as the Inventory Visibility capture.
const String inventoryPhotoCaption = 'Inventory visibility';

/// App-private folder for visit photos. Wiped on sign-out by
/// `DeviceStorageSessionStore.mediaFolders`; rename both together.
const String visitPhotoFolder = 'visit_photos';

/// Stores the inventory photo as a visit photo on this stop.
///
/// It goes into local visit storage first and reaches the server in the
/// stop's next visit push, with the check-out and the other captures. No
/// network is needed here.
///
/// The image is copied into the app's documents folder first: the picker's
/// own file lives in a cache the OS may clear before the push runs.
///
/// A photo that cannot be tied to a stop is not saved, and the skip is
/// logged. A photo with no stop is not evidence of anything. Throws when the
/// local write fails, so the screen keeps the rep on this step.
///
/// Public so the Inventory Availability Survey saves its photos the same way.
Future<void> saveInventoryPhoto({
  required String depotId,
  String? stopId,
  required XFile photo,
  required DateTime takenAt,
}) async {
  final logger = sl.isRegistered<AppLogger>() ? sl<AppLogger>() : null;

  String? resolvedStopId = stopId;
  if (resolvedStopId == null) {
    final result = await sl<GetActiveWorkflow>()(const NoParams());
    final workflow = result.when(success: (w) => w, failure: (_) => null);
    resolvedStopId = workflow?.currentStopId;
  }
  if (resolvedStopId == null) {
    logger?.warning('visit.inventory_photo.not_persisted', fields: {
      'reason': 'noStop',
      'depotId': depotId,
    });
    return;
  }

  final stamp = takenAt.microsecondsSinceEpoch;
  final fileName = 'inventory_$stamp.jpg';
  // Web has no app folder: the picker's blob URL is the only handle there.
  final folder = await appMediaDirectory(visitPhotoFolder);
  final path = folder == null
      ? photo.path
      : await copyCapturedFile(photo.path,
          targetDirectory: folder, fileName: fileName);

  final result = await sl<AddVisitPhoto>()(VisitPhoto(
    id: '$stamp-inventory',
    stopId: resolvedStopId,
    url: path,
    caption: inventoryPhotoCaption,
    takenAt: takenAt,
  ));
  result.when(
    success: (_) {},
    failure: (f) => throw StateError('inventory photo not saved: ${f.message}'),
  );
}

/// Whether the completion screen offers Create Quotation.
const bool _quotationAfterInventory = FeatureFlags.quotesAndOrders;

/// Opens the post-audit decision screen directly.
///
/// Exists so the resume dispatcher lands on the same screen, wired the same
/// way, as the live flow does — the pattern every other step here follows. A
/// resumed visit that reached a subtly different screen is worse than one that
/// did not resume at all.
Future<void> openInventoryCompletion(
  BuildContext context, {
  required String depotId,
  required String depotName,
  String? stopId,
}) async {
  await Navigator.of(context).push(AppPageRoute<void>.sharedAxisVertical(
    settings: const RouteSettings(name: InventoryCompletionScreen.routeName),
    builder: (completionContext) => LocalizedBuilder(
      builder: (_) => InventoryCompletionScreen(
        outletName: depotName,
        showCreateQuotation: _quotationAfterInventory,
        onCreateQuotation: () => _createQuotation(
          completionContext,
          depotId: depotId,
          depotName: depotName,
        ),
        onEndVisit: () => _endVisit(completionContext),
      ),
    ),
  ));
}

/// Stock count logged — swap in the completion screen so the audit step
/// doesn't linger as a separate stack entry underneath the decision it led to.
///
/// Public so the Inventory Availability Survey ends on the same screen.
void continueToInventoryCompletion(
  BuildContext context, {
  required String depotId,
  required String depotName,
  String? stopId,
}) {
  // Move the resume pointer onto the completion step. Without this the audit
  // is finished but the pointer still says "audit", so leaving here and
  // tapping Continue Working sends the rep back to redo a completed count.
  unawaited(sl<UpdateWorkflowStep>()(UpdateWorkflowStepParams(
    VisitWorkflow.stockCount,
    screen: InventoryCompletionScreen.routeName,
    navigationArguments: {
      if (stopId != null) 'stopId': stopId,
      'depotId': depotId,
      'depotName': depotName,
    },
  )));

  Navigator.of(context).pushReplacement(AppPageRoute<void>.fadeThrough(
    settings: const RouteSettings(name: InventoryCompletionScreen.routeName),
    builder: (completionContext) => LocalizedBuilder(
      builder: (_) => InventoryCompletionScreen(
        outletName: depotName,
        showCreateQuotation: _quotationAfterInventory,
        onCreateQuotation: () => _createQuotation(
          completionContext,
          depotId: depotId,
          depotName: depotName,
        ),
        onEndVisit: () => _endVisit(completionContext),
      ),
    ),
  ));
}

/// Drops the (replaced) inventory slot first, so the Quotation Builder lands
/// directly on whatever screen sat below it — the stop review screen on a
/// live check-in, or Home on a cold resume — matching the pre-inventory
/// back-navigation shape rather than stacking on top of a screen the rep has
/// already finished with.
void _createQuotation(
  BuildContext context, {
  required String depotId,
  required String depotName,
}) {
  final navigator = Navigator.of(context);
  navigator.pop();
  openQuotationForDepot(
    navigator.context,
    depotId: depotId,
    depotName: depotName,
  );
}

/// Completes the deferred check-out, clears the resume pointer, backs out of
/// the guided-visit stack, and pushes the day's captures to SAP.
///
/// Delegated to [endVisitAndSync] so this and the Quotation Builder's identical
/// "Complete Visit" cannot drift — and so both get the check-out-before-push
/// ordering that the version inlined here used to get wrong.
void _endVisit(BuildContext context) {
  unawaited(endVisitAndSync(context));
}
