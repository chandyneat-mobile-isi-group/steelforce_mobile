import 'package:dio/dio.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/domain/entities/plan_visit_close.dart';

/// Wire mapping for `POST /mobile/plans/{id}/inventory-check-photo-upload`
/// and `POST /mobile/plans/{id}/check-out`. Neither answer is read: the
/// app only needs to know the server accepted the request.
abstract final class PlanVisitCloseModel {
  /// The multipart body: `uploadId` and the photos in `photos`.
  static Future<FormData> uploadForm(
          PlanInventoryUploadRequest request) async =>
      FormData.fromMap({
        'uploadId': request.uploadId,
        'photos': [
          for (final path in request.photoPaths)
            await MultipartFile.fromFile(
              path,
              filename: _fileName(path),
              // Stated, not left to Dio's `application/octet-stream`: the
              // server takes JPG or PNG only.
              contentType: DioMediaType.parse(_mediaType(_fileName(path))),
            ),
        ],
      });

  /// The JSON body. Coordinates go with a decimal point whatever the device
  /// locale; notes are left out when empty.
  static DataMap checkOutJson(PlanCheckOutRequest request) {
    final notes = request.notes?.trim();
    return {
      'checkOutId': request.checkOutId,
      'latitude': double.parse(request.latitude.toStringAsFixed(6)),
      'longitude': double.parse(request.longitude.toStringAsFixed(6)),
      if (request.accuracyMeters case final accuracy?)
        'accuracyMeters':
            double.parse(accuracy.clamp(0, 10000).toStringAsFixed(1)),
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    };
  }

  static String _fileName(String path) {
    final name = path.split(RegExp(r'[/\\]')).last;
    final lower = name.toLowerCase();
    final known = lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png');
    // The server checks the extension; a camera file without one is a JPEG.
    return known ? name : '$name.jpg';
  }

  static String _mediaType(String fileName) =>
      fileName.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
}
