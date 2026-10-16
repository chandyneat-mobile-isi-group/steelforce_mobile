import 'package:steelforce/core/config/data_source_mode.dart';

/// Features that are built but not yet offered, each switched in one place.
///
/// Compile-time constants, like [DataSourceMode]: a switched-off feature's
/// entry points are hidden, never deleted, and the code is still there to
/// switch back on.
abstract final class FeatureFlags {
  /// Quotations and sales orders. Off in the demo build, where the Orders
  /// tab shows "coming soon" and every Create quotation entry point is
  /// hidden.
  ///
  /// TODO(release-gate): demo-only switch; flip when quotations are ready
  /// to show.
  static const bool quotesAndOrders = !DataSourceMode.useMocks;

  /// The KPI dashboard. Off in the demo build, where tapping the monthly
  /// target opens "coming soon": its figures are still placeholders.
  ///
  /// TODO(release-gate): demo-only switch; flip when KPI reads real data.
  static const bool kpi = !DataSourceMode.useMocks;

  /// The notification inbox. Off in the demo build, where the bell opens
  /// "coming soon" and shows no unread dot.
  ///
  /// TODO(release-gate): demo-only switch; flip when notifications are
  /// ready to show.
  static const bool notifications = !DataSourceMode.useMocks;
}
