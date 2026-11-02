import 'package:flutter/foundation.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/uuid.dart';
import 'package:steelforce/features/my_visits/domain/entities/plan_visit_close.dart';
import 'package:steelforce/features/my_visits/domain/usecases/upload_plan_inventory_photos.dart';
import 'package:steelforce/features/my_visits/presentation/screens/inventory_visible/inventory_visible_screen.dart';

/// The Inventory Visibility save for a planned visit: the photos go to
/// `POST /api/v1/mobile/plans/{id}/inventory-check-photo-upload`, online.
///
/// One upload id per set of photos: a retry of the same photos after a lost
/// answer sends the same id, so the server adds them once; a retaken photo
/// is a new set and gets a new id.
///
/// Throws the [Failure] on a refusal, which keeps the rep on the step with
/// the reason shown. `PLAN_INVENTORY_PHOTO_LIMIT` is not a refusal here: the
/// visit already holds its photos, which is all check-out needs.
Future<void> Function(List<InventoryPhotoCapture> photos) planInventoryUploader(
  String planId, {
  String Function() newId = Uuid.v4,
}) {
  String? uploadId;
  List<String>? sentPaths;
  return (photos) async {
    final paths = [for (final capture in photos) capture.photo.path];
    if (uploadId == null || !listEquals(paths, sentPaths)) {
      uploadId = newId();
      sentPaths = paths;
    }
    final result = await sl<UploadPlanInventoryPhotos>()(
        PlanInventoryUploadRequest(
            planId: planId, uploadId: uploadId!, photoPaths: paths));
    switch (result) {
      case Success():
        return;
      case Failed(:final failure)
          when failure is ServerFailure &&
              failure.code == planInventoryPhotoLimitCode:
        return;
      case Failed(:final failure):
        throw failure;
    }
  };
}
