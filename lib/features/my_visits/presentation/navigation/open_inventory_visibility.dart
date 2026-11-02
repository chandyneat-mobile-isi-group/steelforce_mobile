import 'dart:async';

import 'package:flutter/material.dart';
import 'package:steelforce/core/camera/image_capture_service.dart';
import 'package:steelforce/core/animations/page_transition.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/localization/localized_builder.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_workflow.dart';
import 'package:steelforce/features/my_visits/domain/usecases/update_workflow_step.dart';
import 'package:steelforce/features/my_visits/presentation/navigation/end_visit.dart';
import 'package:steelforce/features/my_visits/presentation/navigation/open_quotation.dart';
import 'package:steelforce/features/my_visits/presentation/navigation/plan_inventory_upload.dart';
import 'package:steelforce/features/my_visits/presentation/navigation/route_inventory_photos.dart';
import 'package:steelforce/features/my_visits/presentation/screens/inventory_visible/inventory_completion_screen.dart';
import 'package:steelforce/features/my_visits/presentation/screens/inventory_visible/inventory_visible_screen.dart';
import 'package:steelforce/features/my_visits/presentation/screens/inventory_visible/plan_check_out_button.dart';

export 'package:steelforce/features/my_visits/presentation/navigation/route_inventory_photos.dart'
    show inventoryPhotoCaption, visitPhotoFolder;

/// Opens the guided Inventory Visibility step (three stock photos) for the
/// checked-in depot — the task that now sits between check-in and the
/// Quotation Builder.
///
/// The single construction path for "audit stock at this shop", so the
/// live check-in flow and the "Continue Working" resume land on the
/// identical screen with identical follow-on actions, exactly like
/// [openQuotationForDepot] does for the quotation step.
///
/// [planId] given — a visit started from a plan — sends the photos to that
/// plan on the server and ends the visit with its check-out. Without it the
/// photos are stored with the route stop and pushed later.
Future<void> openInventoryVisibilityForDepot(
  BuildContext context, {
  required String depotId,
  required String depotName,
  String? stopId,
  String? planId,
}) async {
  await Navigator.of(context).push(AppPageRoute<void>.sharedAxisVertical(
    settings: const RouteSettings(name: InventoryVisibilityScreen.routeName),
    builder: (routeContext) => LocalizedBuilder(
      builder: (_) => InventoryVisibilityScreen(
        depotName: depotName,
        capture: sl<ImageCaptureService>(),
        onPhotosSubmitted: planId != null
            ? planInventoryUploader(planId)
            : (photos) => saveRouteInventoryPhotos(
                  depotId: depotId,
                  stopId: stopId,
                  photos: photos,
                ),
        onSubmit: () => _onInventorySubmitted(
          routeContext,
          depotId: depotId,
          depotName: depotName,
          stopId: stopId,
          planId: planId,
        ),
      ),
    ),
  ));
}

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
    builder: (completionContext) =>
        _completion(completionContext, depotId: depotId, depotName: depotName),
  ));
}

/// A checked-in plan visit's decision screen, opened from Home to check out.
/// The server refuses until the visit holds an inventory photo, and says so.
Future<void> openPlanVisitCompletion(
  BuildContext context, {
  required String depotId,
  required String depotName,
  required String planId,
}) =>
    Navigator.of(context).push(AppPageRoute<void>.sharedAxisVertical(
      settings: const RouteSettings(name: InventoryCompletionScreen.routeName),
      builder: (completionContext) => _completion(completionContext,
          depotId: depotId, depotName: depotName, planId: planId),
    ));

/// The decision screen. A planned visit ([planId]) ends with its check-out;
/// a route visit with the deferred check-out and the push.
Widget _completion(
  BuildContext context, {
  required String depotId,
  required String depotName,
  String? planId,
}) =>
    LocalizedBuilder(
      builder: (_) => InventoryCompletionScreen(
        outletName: depotName,
        photosUploaded: planId != null,
        onCreateQuotation: () => _createQuotation(
          context,
          depotId: depotId,
          depotName: depotName,
        ),
        onEndVisit: () => _endVisit(context),
        checkOutAction: planId == null
            ? null
            : PlanCheckOutButton(
                planId: planId,
                onCheckedOut: (queued) =>
                    PlanCheckOutButton.finish(context, queued: queued),
              ),
      ),
    );

/// Stock count logged — swap in the completion screen so the audit step
/// doesn't linger as a separate stack entry underneath the decision it led to.
void _onInventorySubmitted(
  BuildContext context, {
  required String depotId,
  required String depotName,
  String? stopId,
  String? planId,
}) {
  final navigator = Navigator.of(context);
  final completion = AppPageRoute<void>.fadeThrough(
    settings: const RouteSettings(name: InventoryCompletionScreen.routeName),
    builder: (completionContext) => _completion(completionContext,
        depotId: depotId, depotName: depotName, planId: planId),
  );
  // A planned visit has no route-stop resume pointer to move: writing onto
  // one would retarget whichever route visit owns it.
  if (planId != null) {
    navigator.pushReplacement(completion);
    return;
  }

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

  navigator.pushReplacement(completion);
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
