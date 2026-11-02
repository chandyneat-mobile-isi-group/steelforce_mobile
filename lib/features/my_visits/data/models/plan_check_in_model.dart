import 'package:dio/dio.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/domain/entities/plan_check_in.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_plan.dart';

/// Wire mapping for `GET /mobile/plans/{id}` and
/// `POST /mobile/plans/{id}/check-in` (backend `visit-check-in/api-contract.md`).
abstract final class PlanCheckInModel {
  /// `data` of the plan detail. Throws [FormatException] without an `id`.
  static PlanCheckInTarget targetFromJson(DataMap json) {
    final id = _string(json['id']);
    if (id == null) throw const FormatException('plan detail without an id');
    final location = json['depotLocation'];
    final lat = location is Map ? _double(location['latitude']) : null;
    final lng = location is Map ? _double(location['longitude']) : null;
    final usable = lat != null &&
        lng != null &&
        lat.abs() <= 90 &&
        lng.abs() <= 180 &&
        (lat != 0 || lng != 0);
    return PlanCheckInTarget(
      planId: id,
      status: VisitPlanStatus.fromApi(_string(json['status'])),
      depotCode: _string(json['depotCode']),
      depotName: _string(json['depotName']),
      depotLatitude: usable ? lat : null,
      depotLongitude: usable ? lng : null,
      radiusMeters: _double(json['radiusMeters']),
    );
  }

  /// [target] in the shape [targetFromJson] reads — the device's copy, for
  /// a check-in started offline.
  static DataMap targetToJson(PlanCheckInTarget target) => {
        'id': target.planId,
        'status': target.status.name,
        'depotCode': target.depotCode,
        'depotName': target.depotName,
        'depotLocation': {
          'latitude': target.depotLatitude,
          'longitude': target.depotLongitude,
        },
        'radiusMeters': target.radiusMeters,
      };

  /// `data.checkIn` of the 200 answer. Falls back to the id the app sent when
  /// the server leaves it out — the check-in still landed.
  static PlanCheckInResult resultFromJson(DataMap json, String sentId) {
    final checkIn = json['checkIn'];
    final map = checkIn is Map ? checkIn.cast<String, dynamic>() : const {};
    return PlanCheckInResult(
      checkInId: _string(map['id']) ?? sentId,
      zone: _string(map['zone']) ?? '',
      distanceMeters: _double(map['distanceMeters']),
    );
  }

  /// The multipart body. Coordinates go with a decimal point whatever the
  /// device locale, as the contract asks.
  static Future<FormData> toFormData(PlanCheckInRequest request) async {
    final reason = request.reason;
    final description = request.reasonDescription?.trim();
    final notes = request.notes?.trim();
    return FormData.fromMap({
      'checkInId': request.checkInId,
      'latitude': request.latitude.toStringAsFixed(6),
      'longitude': request.longitude.toStringAsFixed(6),
      if (request.accuracyMeters case final accuracy?)
        'accuracyMeters': accuracy.clamp(0, 10000).toStringAsFixed(1),
      if (reason != null) 'reasonCode': reason.apiValue,
      if (reason != null && description != null && description.isNotEmpty)
        'reasonDescription': description,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
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

  static double? _double(Object? value) {
    final n = switch (value) {
      final num n => n.toDouble(),
      final String s => double.tryParse(s.trim()),
      _ => null,
    };
    return (n == null || !n.isFinite) ? null : n;
  }

  static String? _string(Object? value) {
    if (value == null) return null;
    final text = '$value'.trim();
    return text.isEmpty ? null : text;
  }
}
