import 'package:steelforce/core/localization/localized_text.dart';

/// UI-only status for a completed/attempted visit shown in the visit history
/// flow. Deliberately separate from the real `VisitStatus` domain enum used
/// by the live dispatch flow — this model only ever comes from static mock
/// data, never from a repository.
enum VisitHistoryStatus { completed, missed, pending }

/// Plain, UI-only record for one row in the "My Visits" history list. Backed
/// entirely by static mock data — no repository, database, or network call
/// produces this type.
class VisitRecord {
  const VisitRecord({
    required this.id,
    required this.depotName,
    this.depotNameKh = '',
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.visitDate,
    required this.status,
    this.checkInTime,
    this.checkOutTime,
    this.orderPlaced = false,
    this.collectedAmount,
    this.notes,
    this.photoCount = 0,
    this.phoneNumber,
  });

  final String id;
  final String depotName;

  /// Khmer shop name. Defaulted so the fixture can grow a Khmer name per row
  /// without every construction site changing; empty falls back to
  /// [depotName] via [displayName].
  final String depotNameKh;

  final String address;
  final double latitude;
  final double longitude;
  final DateTime visitDate;
  final VisitHistoryStatus status;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final bool orderPlaced;
  final double? collectedAmount;
  final String? notes;
  final int photoCount;
  final String? phoneNumber;

  /// The shop's name in both languages, resolved at render time like every
  /// other piece of master data in the app — even though this row is a
  /// fixture, it is shaped the way the real visit-history backend will be so
  /// swapping the source is a datasource change, not a UI change.
  LocalizedText get displayName =>
      LocalizedText(en: depotName, km: depotNameKh);

  Duration? get duration {
    if (checkInTime == null || checkOutTime == null) return null;
    return checkOutTime!.difference(checkInTime!);
  }
}
