import 'dart:convert';

import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/domain/entities/plan_check_in.dart';
import 'package:steelforce/features/my_visits/domain/entities/plan_visit_close.dart';

/// The three plan visit steps that can be saved offline, in the order a
/// visit takes them.
enum PlanStepKind { checkIn, inventory, checkOut }

/// A visit step waiting in the outbox. [request] is the step's own request
/// type, rebuilt from the row exactly as it will be sent.
class PlanOutboxStep {
  const PlanOutboxStep({
    required this.request,
    required this.createdAt,
    this.needsAttention = false,
    this.errorCode,
    this.errorMessage,
  });

  /// A [PlanCheckInRequest], [PlanInventoryUploadRequest] or
  /// [PlanCheckOutRequest].
  final Object request;
  final DateTime createdAt;
  final bool needsAttention;

  /// The server's code for the refusal while [needsAttention].
  final String? errorCode;

  /// The localisation key to show while [needsAttention].
  final String? errorMessage;

  String get id => PlanOutboxCodec.idOf(request);
  String get planId => PlanOutboxCodec.planIdOf(request);
  PlanStepKind get kind => PlanOutboxCodec.kindOf(request);
  List<String> get photoPaths => PlanOutboxCodec.photosOf(request);
}

/// A step request to and from the outbox row's `kind` + JSON `payload`.
abstract final class PlanOutboxCodec {
  static PlanStepKind kindOf(Object request) => switch (request) {
        PlanCheckInRequest() => PlanStepKind.checkIn,
        PlanInventoryUploadRequest() => PlanStepKind.inventory,
        PlanCheckOutRequest() => PlanStepKind.checkOut,
        _ => throw ArgumentError('Not a plan visit step: $request'),
      };

  static String idOf(Object request) => switch (request) {
        PlanCheckInRequest(:final checkInId) => checkInId,
        PlanInventoryUploadRequest(:final uploadId) => uploadId,
        PlanCheckOutRequest(:final checkOutId) => checkOutId,
        _ => throw ArgumentError('Not a plan visit step: $request'),
      };

  static String planIdOf(Object request) => switch (request) {
        PlanCheckInRequest(:final planId) ||
        PlanInventoryUploadRequest(:final planId) ||
        PlanCheckOutRequest(:final planId) =>
          planId,
        _ => throw ArgumentError('Not a plan visit step: $request'),
      };

  static List<String> photosOf(Object request) => switch (request) {
        PlanCheckInRequest(:final photoPaths) ||
        PlanInventoryUploadRequest(:final photoPaths) =>
          photoPaths,
        _ => const [],
      };

  static String encode(Object request) => jsonEncode(switch (request) {
        PlanCheckInRequest r => {
            'lat': r.latitude,
            'lng': r.longitude,
            'accuracy': r.accuracyMeters,
            'photos': r.photoPaths,
            'reason': r.reason?.apiValue,
            'description': r.reasonDescription,
            'notes': r.notes,
          },
        PlanInventoryUploadRequest r => {'photos': r.photoPaths},
        PlanCheckOutRequest r => {
            'lat': r.latitude,
            'lng': r.longitude,
            'accuracy': r.accuracyMeters,
            'notes': r.notes,
          },
        _ => throw ArgumentError('Not a plan visit step: $request'),
      });

  /// The request a row holds. Throws [FormatException] for a row this
  /// version cannot read.
  static Object decode({
    required String id,
    required String planId,
    required String kind,
    required String payload,
  }) {
    final json = jsonDecode(payload);
    if (json is! Map) throw const FormatException('outbox payload');
    final p = json.cast<String, dynamic>();
    return switch (kind) {
      'checkIn' => PlanCheckInRequest(
          planId: planId,
          checkInId: id,
          latitude: _num(p, 'lat'),
          longitude: _num(p, 'lng'),
          accuracyMeters: (p['accuracy'] as num?)?.toDouble(),
          photoPaths: _photos(p),
          reason: PlanCheckInReason.values
              .where((r) => r.apiValue == p['reason'])
              .firstOrNull,
          reasonDescription: p['description'] as String?,
          notes: p['notes'] as String?,
        ),
      'inventory' => PlanInventoryUploadRequest(
          planId: planId, uploadId: id, photoPaths: _photos(p)),
      'checkOut' => PlanCheckOutRequest(
          planId: planId,
          checkOutId: id,
          latitude: _num(p, 'lat'),
          longitude: _num(p, 'lng'),
          accuracyMeters: (p['accuracy'] as num?)?.toDouble(),
          notes: p['notes'] as String?,
        ),
      _ => throw FormatException('outbox kind $kind'),
    };
  }

  /// [request] with its photos at [paths] — the outbox's own copies.
  static Object withPhotos(Object request, List<String> paths) =>
      switch (request) {
        PlanCheckInRequest r => PlanCheckInRequest(
            planId: r.planId,
            checkInId: r.checkInId,
            latitude: r.latitude,
            longitude: r.longitude,
            accuracyMeters: r.accuracyMeters,
            photoPaths: paths,
            reason: r.reason,
            reasonDescription: r.reasonDescription,
            notes: r.notes,
          ),
        PlanInventoryUploadRequest r => PlanInventoryUploadRequest(
            planId: r.planId, uploadId: r.uploadId, photoPaths: paths),
        _ => request,
      };

  static double _num(DataMap p, String key) {
    final v = p[key];
    if (v is! num) throw FormatException('outbox $key');
    return v.toDouble();
  }

  static List<String> _photos(DataMap p) =>
      (p['photos'] as List? ?? const []).whereType<String>().toList();
}
