import 'package:flutter/foundation.dart';

/// A day the Visits tab should show next — set by a notification such as
/// `visit-plans / 2026-10-22`, taken by `VisitPlansScreen`.
///
/// A holder rather than a route argument: the Visits tab lives in the shell's
/// `IndexedStack`, so it is selected, not pushed, and may already be built.
class VisitPlanDayRequest extends ValueNotifier<DateTime?> {
  VisitPlanDayRequest() : super(null);

  /// Asks for [day]; `yyyy-MM-dd` strings come through [openIso].
  void open(DateTime day) => value = DateTime(day.year, day.month, day.day);

  /// Parses an ISO date (`2026-10-22`). Returns false, asking for nothing,
  /// when [raw] is not one.
  bool openIso(String? raw) {
    final day = raw == null ? null : DateTime.tryParse(raw);
    if (day == null) return false;
    open(day);
    return true;
  }

  /// Returns and clears the pending day, so it is shown once.
  DateTime? take() {
    final day = value;
    if (day != null) value = null;
    return day;
  }
}
