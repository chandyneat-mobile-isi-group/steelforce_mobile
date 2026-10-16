import 'package:equatable/equatable.dart';

/// Response to a [VisitPushBatch] push — which row ids the backend accepted,
/// rejected (kept `pending` for a future retry) or discarded, and when it
/// happened.
class VisitPushResult extends Equatable {
  const VisitPushResult({
    required this.acceptedIds,
    required this.rejectedIds,
    required this.syncedAt,
    this.discardedIds = const [],
    this.discardReasons = const {},
  });

  final List<String> acceptedIds;

  /// Transient failures. Stay `pending`; the next push sends them again.
  final List<String> rejectedIds;

  /// **Permanently invalid — the server will never store these.**
  ///
  /// The resolution of OPEN-2 (api.md §6.1). Before this bucket existed, a row
  /// the server could not store came back in neither list, which the client
  /// treats as rejected, which means it is sent again on every push for the
  /// life of the install. Reading it is what ends that cycle.
  final List<String> discardedIds;

  /// Stable `errorCode` per discarded id, from the response's `discarded`
  /// array. Developer-facing — it is logged, never shown to a rep, who can do
  /// nothing about `Visit.StopNotFound` on a row they captured last Tuesday.
  final Map<String, String> discardReasons;

  final DateTime syncedAt;

  @override
  List<Object?> get props =>
      [acceptedIds, rejectedIds, discardedIds, discardReasons, syncedAt];
}
