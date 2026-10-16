import 'package:equatable/equatable.dart';

/// Covers general notes, competitor-activity observations, and quick
/// surveys — all free-text capture at a stop, distinguished only by [type]
/// so the timeline/UI can label them differently without three near-
/// identical entities.
enum VisitNoteType { general, competitorActivity, survey }

class VisitNote extends Equatable {
  const VisitNote({
    required this.id,
    required this.stopId,
    required this.type,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String stopId;
  final VisitNoteType type;
  final String text;
  final DateTime createdAt;

  @override
  List<Object?> get props => [id, stopId, type, text, createdAt];
}
