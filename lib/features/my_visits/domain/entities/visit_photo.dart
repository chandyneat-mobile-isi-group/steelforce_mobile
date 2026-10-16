import 'package:equatable/equatable.dart';

/// Covers both visit photos and the depot signature capture — a
/// signature is just a photo-shaped capture with [isSignature] set, since
/// this demo mocks capture (no real camera/signature-pad wiring, matching
/// the same mock-capture precedent `DocumentsSection` already uses in the
/// Lead feature) rather than adding a whole separate entity for one field.
class VisitPhoto extends Equatable {
  const VisitPhoto({
    required this.id,
    required this.stopId,
    required this.url,
    required this.caption,
    required this.takenAt,
    this.isSignature = false,
  });

  final String id;
  final String stopId;
  final String url;
  final String caption;
  final DateTime takenAt;
  final bool isSignature;

  @override
  List<Object?> get props => [id, stopId, url, isSignature, takenAt];
}
