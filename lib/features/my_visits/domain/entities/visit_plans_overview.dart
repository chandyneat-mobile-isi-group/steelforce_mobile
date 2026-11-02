import 'package:equatable/equatable.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_plan.dart';

/// The rep's plan for one period: the server's counts and every visit in it.
///
/// The counts are the server's, not recomputed from [items] — `remaining`
/// follows a rule (planned not yet missed, plus checked in) that the app has no
/// business re-deriving.
class VisitPlansOverview extends Equatable {
  const VisitPlansOverview({
    required this.period,
    required this.from,
    required this.to,
    required this.total,
    required this.completed,
    required this.remaining,
    required this.skipped,
    required this.missed,
    required this.adHoc,
    required this.items,
    this.savedAt,
  });

  final String period;
  final DateTime? from;
  final DateTime? to;
  final int total;
  final int completed;
  final int remaining;
  final int skipped;
  final int missed;

  /// Null when the response carried no usable count.
  final int? adHoc;

  /// In the server's order: by date, then depot code.
  final List<VisitPlan> items;

  /// Set when this came from the device rather than the server — offline,
  /// the plan as it was at this moment. Null for a live answer.
  final DateTime? savedAt;

  bool get isEmpty => items.isEmpty;

  /// The same plan, marked as read from the device's copy saved at [at].
  /// The same answer with [items] in place of its own — the plans as this
  /// device has worked them.
  VisitPlansOverview withItems(List<VisitPlan> items) => VisitPlansOverview(
        period: period,
        from: from,
        to: to,
        total: total,
        completed: completed,
        remaining: remaining,
        skipped: skipped,
        missed: missed,
        adHoc: adHoc,
        items: items,
        savedAt: savedAt,
      );

  VisitPlansOverview savedCopy(DateTime at) => VisitPlansOverview(
        period: period,
        from: from,
        to: to,
        total: total,
        completed: completed,
        remaining: remaining,
        skipped: skipped,
        missed: missed,
        adHoc: adHoc,
        items: items,
        savedAt: at,
      );

  /// The visits assigned to [day] (any time of day), in the server's order.
  List<VisitPlan> plansOn(DateTime day) => [
        for (final plan in items)
          if (plan.assignmentDate case final date?
              when date.year == day.year &&
                  date.month == day.month &&
                  date.day == day.day)
            plan,
      ];

  /// [plans] grouped by assignment day, days ascending; undated visits last.
  /// Within a day the given order is kept.
  static List<(DateTime?, List<VisitPlan>)> groupByDay(List<VisitPlan> plans) {
    final groups = <DateTime?, List<VisitPlan>>{};
    for (final plan in plans) {
      groups.putIfAbsent(plan.assignmentDate, () => []).add(plan);
    }
    final days = groups.keys.whereType<DateTime>().toList()..sort();
    return [
      for (final day in days) (day, groups[day]!),
      if (groups.containsKey(null)) (null, groups[null]!),
    ];
  }

  @override
  List<Object?> get props => [
        period,
        from,
        to,
        total,
        completed,
        remaining,
        skipped,
        missed,
        adHoc,
        items,
        savedAt,
      ];
}
