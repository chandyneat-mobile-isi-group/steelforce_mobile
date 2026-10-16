import 'package:steelforce/core/network/api/api_envelope.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/domain/entities/no_order_reason.dart';
import 'package:steelforce/features/my_visits/domain/entities/server_visit.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_status.dart';

/// Reads a `VisitDto` (`check-in-check-out-mobile.md` §8). Defensive: an
/// unreadable field degrades to null rather than throwing, because the row
/// it answers for is already saved on the device.
ServerVisit serverVisitFromJson(DataMap json) {
  final checkIn = json['checkIn'];
  final checkOut = json['checkOut'];
  return ServerVisit(
    visitId: json['visitId'] as String?,
    stopId: (json['stopId'] as String?) ?? '',
    status:
        VisitStatus.values.asNameMap()[json['status']] ?? VisitStatus.pending,
    checkedInAt: checkIn is Map ? parseUtc(checkIn['timestamp']) : null,
    checkedOutAt: checkOut is Map ? parseUtc(checkOut['timestamp']) : null,
    flagged: checkIn is Map && checkIn['flagged'] == true,
  );
}

NoOrderReason? noOrderReasonFromJson(DataMap json) {
  final code = json['code'];
  if (code is! String || code.isEmpty) return null;
  return NoOrderReason(
    code: code,
    nameEn: (json['nameEn'] as String?) ?? code,
    nameKm: (json['nameKm'] as String?) ?? '',
    requiresNote: json['requiresNote'] == true,
    sort: (json['sort'] as num?)?.toInt() ?? 0,
  );
}

DataMap noOrderReasonToJson(NoOrderReason r) => {
      'code': r.code,
      'nameEn': r.nameEn,
      'nameKm': r.nameKm,
      'requiresNote': r.requiresNote,
      'sort': r.sort,
    };
