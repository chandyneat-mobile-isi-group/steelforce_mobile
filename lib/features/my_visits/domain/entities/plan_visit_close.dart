import 'package:equatable/equatable.dart';

/// Whether a visit step reached the server now, or was saved on the device
/// to be sent when it can be.
enum PlanStepDelivery { sent, queued }

/// One stock-photo upload to a checked-in plan. [uploadId] is made once per
/// batch and sent again on every retry, so a lost answer never adds the
/// photos twice.
class PlanInventoryUploadRequest extends Equatable {
  const PlanInventoryUploadRequest({
    required this.planId,
    required this.uploadId,
    required this.photoPaths,
  });

  final String planId;
  final String uploadId;

  /// 1 to [maxPhotos] local `.jpg`, `.jpeg` or `.png` files.
  final List<String> photoPaths;

  /// The most a visit holds, across all its uploads.
  static const maxPhotos = 10;

  @override
  List<Object?> get props => [planId, uploadId, photoPaths];
}

/// The server's code for "this visit already holds the most photos it can".
/// The visit then has its photos, so check-out is still possible.
const planInventoryPhotoLimitCode = 'PLAN_INVENTORY_PHOTO_LIMIT';

/// One check-out attempt. [checkOutId] is made once per screen and sent on
/// every retry, so a lost answer returns the closed visit instead of a 409.
class PlanCheckOutRequest extends Equatable {
  const PlanCheckOutRequest({
    required this.planId,
    required this.checkOutId,
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
    this.notes,
  });

  final String planId;
  final String checkOutId;
  final double latitude;
  final double longitude;
  final double? accuracyMeters;

  /// Optional, up to [maxNotesLength].
  final String? notes;

  static const maxNotesLength = 1000;

  @override
  List<Object?> get props =>
      [planId, checkOutId, latitude, longitude, accuracyMeters, notes];
}
