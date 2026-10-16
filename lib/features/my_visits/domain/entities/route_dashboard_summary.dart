import 'package:equatable/equatable.dart';

class RouteDashboardSummary extends Equatable {
  const RouteDashboardSummary({
    required this.stopsToday,
    required this.completed,
    required this.remaining,
    required this.missed,
    required this.progress,
    required this.totalDistanceKm,
    required this.drivingTimeMinutes,
    required this.visitTimeMinutes,
    required this.totalCollections,
    required this.totalOrders,
    required this.totalSalesValue,
    required this.successRate,
  });

  final int stopsToday;
  final int completed;
  final int remaining;
  final int missed;
  final double progress;
  final double totalDistanceKm;
  final int drivingTimeMinutes;
  final int visitTimeMinutes;
  final double totalCollections;
  final int totalOrders;
  final double totalSalesValue;
  final double successRate;

  @override
  List<Object?> get props =>
      [stopsToday, completed, remaining, missed, totalSalesValue];
}
