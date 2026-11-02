import 'package:steelforce/features/my_visits/data/remote/plan_visit_debug_log.dart';
import 'package:steelforce/features/my_visits/domain/entities/ad_hoc_plan.dart';
import 'package:steelforce/features/my_visits/domain/entities/plan_check_in.dart';
import 'package:steelforce/features/my_visits/domain/entities/plan_visit_close.dart';

/// What each plan visit request carries, as [PlanVisitDebugLog] rows.
///
/// Positions show as present plus accuracy, never the coordinates; free text
/// as its length, never its words.
abstract final class PlanVisitRequestRows {
  static String Function(String, Object?) get _row => PlanVisitDebugLog.row;

  static List<String> adHoc(String visitId, AdHocPlanOutlet outlet) => [
        _row('visitId', visitId),
        _row('outletType', '${outlet.type.apiValue} (${outlet.type.name})'),
        if (outlet.depotCode case final code?) _row('depotCode', code),
        if (outlet.nonDepotId case final id?) _row('nonDepotId', id),
      ];

  static List<String> checkIn(PlanCheckInRequest r) => [
        _row('content', 'multipart/form-data'),
        _row('planId', r.planId),
        _row('checkInId', r.checkInId),
        ..._position(r.latitude, r.longitude, r.accuracyMeters),
        if (r.reason case final reason?) _row('reason', reason.apiValue),
        _row('description', _text(r.reasonDescription)),
        _row('notes', _text(r.notes)),
        ...PlanVisitDebugLog.photoRows(r.photoPaths),
      ];

  static List<String> inventory(PlanInventoryUploadRequest r) => [
        _row('content', 'multipart/form-data'),
        _row('planId', r.planId),
        _row('uploadId', r.uploadId),
        ...PlanVisitDebugLog.photoRows(r.photoPaths),
      ];

  static List<String> checkOut(PlanCheckOutRequest r) => [
        _row('content', 'application/json'),
        _row('planId', r.planId),
        _row('checkOutId', r.checkOutId),
        ..._position(r.latitude, r.longitude, r.accuracyMeters),
        _row('notes', _text(r.notes)),
      ];

  static List<String> _position(double lat, double lng, double? accuracy) => [
        _row('position', lat.isFinite && lng.isFinite ? 'present' : 'MISSING'),
        _row('accuracy', accuracy == null ? '-' : '${accuracy.round()} m'),
      ];

  static String _text(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty ? 'none' : '${text.length} chars';
  }
}
