import 'dart:convert';

import 'package:steelforce/features/depots/domain/entities/depot_document.dart';

/// One photograph a queued registration is still holding.
///
/// [encode] is the stored `attachments` column of the registration queue.
/// Rows already on devices are read back by later versions, so the format is
/// pinned by `test/features/depots/depot_registration_outbox_test.dart`.
class QueuedPhoto {
  const QueuedPhoto(this.type, this.path, this.capturedAt);

  final DepotDocumentType type;
  final String path;
  final DateTime capturedAt;

  static String encode(List<QueuedPhoto> photos) => jsonEncode([
        for (final p in photos)
          {
            'type': p.type.name,
            'path': p.path,
            'capturedAt': p.capturedAt.toIso8601String(),
          },
      ]);

  /// Tolerant: an unreadable entry is skipped rather than failing the row.
  static List<QueuedPhoto> decode(String raw) {
    try {
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      final out = <QueuedPhoto>[];
      for (final e in list.whereType<Map>()) {
        final type = DepotDocumentType.values
            .where((t) => t.name == e['type'])
            .firstOrNull;
        final path = e['path'];
        if (type == null || path is! String) continue;
        out.add(
          QueuedPhoto(
            type,
            path,
            DateTime.tryParse('${e['capturedAt']}') ?? DateTime.now().toUtc(),
          ),
        );
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  /// The file extension of [path], `.jpg` when it has none.
  static String extensionOf(String path) {
    final dot = path.lastIndexOf('.');
    final slash = path.lastIndexOf('/');
    return dot > slash && dot >= 0 ? path.substring(dot) : '.jpg';
  }
}
