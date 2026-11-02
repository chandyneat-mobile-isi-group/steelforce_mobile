import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_plan.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_plans_overview.dart';

/// Reads `data` of `GET /api/v1/mobile/plans` (`MyPlansView`) into the domain.
///
/// Tolerant by design: a missing count reads as 0, a missing name as null, and
/// a numeric field sent as a string still parses. The one hard requirement is
/// an item's `id` — without the plan id nothing can ever be done with the
/// visit, so such an item is dropped rather than shown as a dead card.
abstract final class VisitPlansModel {
  static VisitPlansOverview fromJson(DataMap json) {
    final rawItems = json['items'];
    final items = <VisitPlan>[
      if (rawItems is List)
        for (final raw in rawItems.whereType<Map>())
          if (itemFromJson(raw.cast<String, dynamic>()) case final plan?) plan,
    ];
    return VisitPlansOverview(
      period: _string(json['period']) ?? '',
      from: _date(json['from']),
      to: _date(json['to']),
      total: _int(json['total']) ?? 0,
      completed: _int(json['completed']) ?? 0,
      remaining: _int(json['remaining']) ?? 0,
      skipped: _int(json['skipped']) ?? 0,
      missed: _int(json['missed']) ?? 0,
      adHoc: _int(json['adHoc']),
      items: items,
    );
  }

  /// [overview] back in the wire shape [fromJson] reads, for the device's
  /// copy. `fromJson(toJson(x))` gives `x` again.
  static DataMap toJson(VisitPlansOverview overview) => {
        'period': overview.period,
        'from': _day(overview.from),
        'to': _day(overview.to),
        'total': overview.total,
        'completed': overview.completed,
        'remaining': overview.remaining,
        'skipped': overview.skipped,
        'missed': overview.missed,
        'adHoc': overview.adHoc,
        'items': [
          for (final plan in overview.items)
            {
              'id': plan.id,
              'assignmentDate': _day(plan.assignmentDate),
              'visitType': plan.visitType,
              'outletType': plan.outletType,
              'status': plan.rawStatus,
              'depotCode': plan.depotCode,
              'nonDepotId': plan.nonDepotId,
              'outletName': plan.outletName,
              'depotName': plan.depotName,
              'depotType': plan.depotType,
              'depotTier': plan.depotTier,
              'territoryCode': plan.territoryCode,
              'latitude': plan.latitude,
              'longitude': plan.longitude,
            },
        ],
      };

  static String? _day(DateTime? d) => d == null
      ? null
      : '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';

  /// One plan item; null without an `id`.
  static VisitPlan? itemFromJson(DataMap json) {
    final id = _string(json['id']);
    if (id == null) return null;
    final status = _string(json['status']) ?? '';
    final location = _location(json['latitude'], json['longitude']);
    return VisitPlan(
      id: id,
      assignmentDate: _date(json['assignmentDate']),
      visitType: _string(json['visitType']) ?? '',
      outletType: _string(json['outletType']) ?? '',
      status: VisitPlanStatus.fromApi(status),
      rawStatus: status,
      depotCode: _string(json['depotCode']),
      nonDepotId: _string(json['nonDepotId']),
      outletName: _string(json['outletName']),
      depotName: _string(json['depotName']),
      depotType: _string(json['depotType']),
      depotTier: _string(json['depotTier']),
      territoryCode: _string(json['territoryCode']),
      latitude: location?.$1,
      longitude: location?.$2,
    );
  }

  /// Both coordinates, or neither. One without the other, or a value outside
  /// the globe, is no location at all rather than a pin in the wrong place.
  static (double, double)? _location(Object? lat, Object? lng) {
    final la = _double(lat);
    final lo = _double(lng);
    if (la == null || lo == null) return null;
    if (la.abs() > 90 || lo.abs() > 180) return null;
    return (la, lo);
  }

  static double? _double(Object? value) {
    final n = switch (value) {
      final num n => n.toDouble(),
      final String s => double.tryParse(s.trim()),
      _ => null,
    };
    return (n == null || !n.isFinite) ? null : n;
  }

  /// A non-blank string, or null.
  static String? _string(Object? value) {
    if (value == null) return null;
    final text = '$value'.trim();
    return text.isEmpty ? null : text;
  }

  static int? _int(Object? value) => switch (value) {
        final num n => n.toInt(),
        final String s => int.tryParse(s.trim()),
        _ => null,
      };

  /// The calendar day in a `yyyy-MM-dd…` value, at local midnight.
  ///
  /// Read from the text, never through `DateTime.parse(...).toLocal()`: the
  /// server's day is already the business day, and shifting a UTC instant into
  /// the device zone can move it onto the neighbouring date.
  static DateTime? _date(Object? value) {
    final match =
        RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch('${value ?? ''}');
    if (match == null) return null;
    return DateTime(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }
}
