import 'package:equatable/equatable.dart';

class VisitPushSummary extends Equatable {
  const VisitPushSummary({required this.pushedCount, required this.syncedAt});

  final int pushedCount;
  final DateTime syncedAt;

  @override
  List<Object?> get props => [pushedCount, syncedAt];
}
