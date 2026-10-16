import 'package:steelforce/core/network/api/api_envelope.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/depots/domain/entities/depot_document.dart';

/// Maps the depot-documents API onto the domain entities.
///
/// Tolerant by design, like every other mapper here: a field the server omits
/// degrades rather than throwing, because one unexpected null must not blank a
/// rep's evidence screen.
abstract final class DepotDocumentMapper {
  static DepotDocument? fromJson(DataMap json) {
    final type = DepotDocumentType.fromCode(json['type'] as String?);
    // A slot this build does not recognise is skipped rather than crashing the
    // list — the server may gain a sixth before the app ships again.
    if (type == null) return null;

    return DepotDocument(
      id: json['id']?.toString() ?? '',
      type: type,
      typeDisplay: json['typeDisplay'] as String?,
      fileName: json['fileName'] as String? ?? '',
      contentType: json['contentType'] as String?,
      sizeBytes: (json['sizeBytes'] as num?)?.toInt(),
      url: json['url'] as String?,
      // Null for the non-public slots, by design. Read it, never derive it.
      publicUrl: json['publicUrl'] as String?,
      isPubliclyVisible: json['isPubliclyVisible'] as bool? ?? false,
      capturedAt: parseUtc(json['capturedAt']),
      uploadedAt: parseUtc(json['uploadedAt']),
    );
  }

  /// The `GET …/documents` body.
  static DepotDocumentsState stateFromJson(DataMap data) {
    final rows = data['documents'];
    final byType = <DepotDocumentType, DepotDocument>{};
    if (rows is List) {
      for (final row in rows) {
        if (row is! Map) continue;
        final document = fromJson(row.cast<String, dynamic>());
        // One live document per slot, so a later row for the same slot is the
        // current one.
        if (document != null) byType[document.type] = document;
      }
    }

    final missing = <DepotDocumentType>{};
    final rawMissing = data['missingRequired'];
    if (rawMissing is List) {
      for (final code in rawMissing) {
        final type = DepotDocumentType.fromCode(code?.toString());
        if (type != null) missing.add(type);
      }
    }

    return DepotDocumentsState(
      byType: byType,
      missingRequired: missing,
      // Read, never recomputed from `missingRequired.isEmpty`: the server owns
      // which slots count as required, and that rule can change without this
      // app being redeployed.
      isComplete: data['isComplete'] == true,
    );
  }
}
