import 'package:equatable/equatable.dart';

/// Visit work saved on this device that the server does not have yet, for
/// the Sync Center.
class PendingVisitSync extends Equatable {
  const PendingVisitSync({this.stops = const [], this.otherRecords = 0});

  /// One entry per stop with **any** unsent row — a check-in, a check-out, or
  /// only captures (stock counts, notes, photos, …) — oldest first.
  final List<PendingVisitStop> stops;

  /// Unsent rows that belong to no stop (a stock count taken from a depot's
  /// own page). They cannot be acted on per stop; they are counted here so
  /// `stops` plus this always equals the visit rows still on the device.
  final int otherRecords;

  bool get isEmpty => stops.isEmpty && otherRecords == 0;

  @override
  List<Object?> get props => [stops, otherRecords];
}

class PendingVisitStop extends Equatable {
  const PendingVisitStop({
    required this.stopId,
    this.shopName,
    this.shopNameKh,
    this.checkInAt,
    this.checkOutAt,
    this.orderLines = 0,
    this.stockUpdates = 0,
    this.returns = 0,
    this.collections = 0,
    this.notes = 0,
    this.photos = 0,
    this.photoFiles = const [],
    this.noteTexts = const [],
  });

  final String stopId;

  /// Null when the stop's shop is not on the device (an older route).
  final String? shopName;
  final String? shopNameKh;

  /// Set when this stop's check-in is still waiting to be sent.
  final DateTime? checkInAt;

  /// Set when this stop's check-out is still waiting to be sent.
  final DateTime? checkOutAt;

  /// Unsent captures at this stop, by kind.
  final int orderLines;
  final int stockUpdates;
  final int returns;
  final int collections;
  final int notes;
  final int photos;

  /// The photographs themselves, oldest first, for the Sync Center's details
  /// view. Shown on this device only, never logged.
  final List<PendingVisitPhoto> photoFiles;

  /// What the rep wrote in each unsent note, oldest first.
  final List<String> noteTexts;

  /// The check-out is held until the check-in reaches the server.
  bool get checkOutWaitsForCheckIn => checkInAt != null && checkOutAt != null;

  /// Every unsent capture at this stop, check-in and check-out excluded.
  int get captureCount =>
      orderLines + stockUpdates + returns + collections + notes + photos;

  /// Every unsent row at this stop, check-in and check-out included.
  int get recordCount =>
      captureCount + (checkInAt == null ? 0 : 1) + (checkOutAt == null ? 0 : 1);

  @override
  List<Object?> get props => [
        stopId,
        shopName,
        shopNameKh,
        checkInAt,
        checkOutAt,
        orderLines,
        stockUpdates,
        returns,
        collections,
        notes,
        photos,
        photoFiles,
        noteTexts,
      ];
}

/// One photograph a visit holds on the device, waiting to be sent.
class PendingVisitPhoto extends Equatable {
  const PendingVisitPhoto({
    required this.path,
    required this.takenAt,
    this.caption = '',
    this.isSignature = false,
  });

  /// Local file path (or, for an already-uploaded legacy row, a URL).
  final String path;
  final DateTime takenAt;
  final String caption;
  final bool isSignature;

  @override
  List<Object?> get props => [path, takenAt, caption, isSignature];
}
