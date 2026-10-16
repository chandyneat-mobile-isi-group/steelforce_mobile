import 'package:equatable/equatable.dart';

enum ActivityKind { lead, order, opportunity, payment }

class ActivityItem extends Equatable {
  const ActivityItem({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.timeAgo,
  });

  final ActivityKind kind;
  final String title;
  final String subtitle;
  final String timeAgo;

  @override
  List<Object?> get props => [kind, title, subtitle, timeAgo];
}

class DashboardSummary extends Equatable {
  const DashboardSummary({
    required this.newLeads,
    required this.openOrders,
    required this.openOpportunities,
    required this.wonDeals,
    required this.totalDepots,
    required this.totalRoutes,
    required this.revenueMtd,
    required this.winRate,
    required this.targetProgress,
    required this.recent,
  });

  final int newLeads;
  final int openOrders;
  final int openOpportunities;
  final int wonDeals;
  final int totalDepots;
  final int totalRoutes;
  final String revenueMtd; // pre-formatted for display
  final double winRate; // 0..1
  final double targetProgress; // 0..1
  final List<ActivityItem> recent;

  @override
  List<Object?> get props => [
        newLeads,
        openOrders,
        totalDepots,
        totalRoutes,
        revenueMtd,
        winRate,
        targetProgress,
        recent,
      ];
}
