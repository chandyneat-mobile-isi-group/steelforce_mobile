import 'package:steelforce/features/shell/domain/dashboard_summary.dart';

abstract interface class HomeRepository {
  Future<DashboardSummary> fetchSummary();
}

/// Sample data so the screen runs today. Replace the body with your API
/// call (keep the same signature) — nothing else needs to change.
class HomeRepositoryImpl implements HomeRepository {
  const HomeRepositoryImpl();

  @override
  Future<DashboardSummary> fetchSummary() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return const DashboardSummary(
      newLeads: 12,
      openOpportunities: 5,
      wonDeals: 80,
      openOrders: 8,
      totalDepots: 120,
      totalRoutes: 5,
      revenueMtd: '\$48.2k',
      winRate: 0.34,
      targetProgress: 0.62,
      recent: [
        ActivityItem(
          kind: ActivityKind.order,
          title: 'PO #4821 confirmed',
          subtitle: 'Mekong Construction · 24t rebar',
          timeAgo: '12m',
        ),
        ActivityItem(
          kind: ActivityKind.lead,
          title: 'New lead assigned',
          subtitle: 'Sokha Metalworks',
          timeAgo: '1h',
        ),
        ActivityItem(
          kind: ActivityKind.opportunity,
          title: 'Quote sent',
          subtitle: 'Angkor Steel · \$18,400',
          timeAgo: '3h',
        ),
        ActivityItem(
          kind: ActivityKind.payment,
          title: 'Payment received',
          subtitle: 'Invoice #2290 · \$9,100',
          timeAgo: '5h',
        ),
      ],
    );
  }
}
