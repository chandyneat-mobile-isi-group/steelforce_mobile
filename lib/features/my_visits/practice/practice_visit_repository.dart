import 'package:steelforce/core/practice/practice_ids.dart';
import 'package:steelforce/core/practice/practice_session.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/domain/entities/check_in_record.dart';
import 'package:steelforce/features/my_visits/domain/entities/check_out_record.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_collection.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_note.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_order_line.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_photo.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_return.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_send_result.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_stock_update.dart';
import 'package:steelforce/features/my_visits/domain/repositories/visit_repository.dart';
import 'package:steelforce/features/my_visits/practice/practice_photo_files.dart';

/// [VisitRepository] for a practice lesson.
///
/// Everything captured at a practice stop — check-in, check-out, photos,
/// notes, order lines — lives in memory for the length of the lesson. Nothing
/// reaches the encrypted database or the sync queue, and `send…` answers
/// "sent" without a request: there is no server visit to create.
///
/// A record for a **real** stop goes to the real repository, so practice never
/// swallows real work. Once [PracticeWorld.isClosed], every call does.
///
/// Photos captured for a practice stop are files on disk (the camera wrote
/// them); their paths are remembered and the files deleted when the lesson
/// ends.
class PracticeVisitRepository implements VisitRepository {
  PracticeVisitRepository(
    this._real,
    this._world, {
    Future<void> Function(String path)? deleteFile,
  }) : _deleteFile = deleteFile ?? deletePracticePhotoFile {
    _world.onClose(_deletePhotoFiles);
  }

  final VisitRepository _real;
  final PracticeWorld _world;
  final Future<void> Function(String path) _deleteFile;

  final List<CheckInRecord> checkIns = [];
  final List<CheckOutRecord> checkOuts = [];
  final List<VisitOrderLine> _orderLines = [];
  final List<VisitStockUpdate> _stockUpdates = [];
  final List<VisitReturn> _returns = [];
  final List<VisitCollection> _collections = [];
  final List<VisitNote> _notes = [];
  final List<VisitPhoto> _photos = [];

  /// Files to delete when the lesson ends.
  final Set<String> _photoFiles = {};

  /// True while [id] belongs to the practice world and the lesson is running.
  bool _practice(String? id) => !_world.isClosed && PracticeIds.isPractice(id);

  Future<void> _deletePhotoFiles() async {
    final files = [..._photoFiles];
    _photoFiles.clear();
    for (final path in files) {
      await _deleteFile(path);
    }
  }

  @override
  ResultFuture<CheckInRecord> checkIn(CheckInRecord record) async {
    if (!_practice(record.stopId)) return _real.checkIn(record);
    checkIns.add(record);
    return Success(record);
  }

  @override
  ResultFuture<CheckOutRecord> checkOut(CheckOutRecord record) async {
    if (!_practice(record.stopId)) return _real.checkOut(record);
    checkOuts.add(record);
    return Success(record);
  }

  @override
  ResultFuture<VisitSendResult> sendCheckIn(CheckInRecord record) async {
    if (!_practice(record.stopId)) return _real.sendCheckIn(record);
    return const Success(VisitSendResult(VisitSendStatus.sent));
  }

  @override
  ResultFuture<VisitSendResult> sendCheckOut(CheckOutRecord record) async {
    if (!_practice(record.stopId)) return _real.sendCheckOut(record);
    return const Success(VisitSendResult(VisitSendStatus.sent));
  }

  @override
  ResultFuture<String?> checkInIdForStop(String stopId) async {
    if (!_practice(stopId)) return _real.checkInIdForStop(stopId);
    for (final record in checkIns.reversed) {
      if (record.stopId == stopId) return Success(record.id);
    }
    return const Success(null);
  }

  @override
  ResultFuture<void> addOrderLine(VisitOrderLine line) async {
    if (!_practice(line.stopId)) return _real.addOrderLine(line);
    _orderLines.add(line);
    return const Success(null);
  }

  @override
  ResultFuture<void> addStockUpdate(VisitStockUpdate update) async {
    if (!_practice(update.stopId ?? update.depotId)) {
      return _real.addStockUpdate(update);
    }
    _stockUpdates.add(update);
    return const Success(null);
  }

  @override
  ResultFuture<void> addReturn(VisitReturn returnItem) async {
    if (!_practice(returnItem.stopId)) return _real.addReturn(returnItem);
    _returns.add(returnItem);
    return const Success(null);
  }

  @override
  ResultFuture<void> addCollection(VisitCollection collection) async {
    if (!_practice(collection.stopId)) return _real.addCollection(collection);
    _collections.add(collection);
    return const Success(null);
  }

  @override
  ResultFuture<void> addNote(VisitNote note) async {
    if (!_practice(note.stopId)) return _real.addNote(note);
    _notes.add(note);
    return const Success(null);
  }

  @override
  ResultFuture<void> addPhoto(VisitPhoto photo) async {
    if (!_practice(photo.stopId)) return _real.addPhoto(photo);
    _photos.add(photo);
    if (photo.url.isNotEmpty) _photoFiles.add(photo.url);
    return const Success(null);
  }

  @override
  ResultFuture<List<VisitOrderLine>> fetchOrderLines(String stopId) async {
    if (!_practice(stopId)) return _real.fetchOrderLines(stopId);
    return Success(_orderLines.where((l) => l.stopId == stopId).toList());
  }

  @override
  ResultFuture<List<VisitStockUpdate>> fetchStockUpdates(String stopId) async {
    if (!_practice(stopId)) return _real.fetchStockUpdates(stopId);
    return Success(_stockUpdates.where((u) => u.stopId == stopId).toList());
  }

  @override
  ResultFuture<List<VisitReturn>> fetchReturns(String stopId) async {
    if (!_practice(stopId)) return _real.fetchReturns(stopId);
    return Success(_returns.where((r) => r.stopId == stopId).toList());
  }

  @override
  ResultFuture<List<VisitCollection>> fetchCollections(String stopId) async {
    if (!_practice(stopId)) return _real.fetchCollections(stopId);
    return Success(_collections.where((c) => c.stopId == stopId).toList());
  }

  @override
  ResultFuture<List<VisitNote>> fetchNotes(String stopId) async {
    if (!_practice(stopId)) return _real.fetchNotes(stopId);
    return Success(_notes.where((n) => n.stopId == stopId).toList());
  }

  @override
  ResultFuture<List<VisitPhoto>> fetchPhotos(String stopId) async {
    if (!_practice(stopId)) return _real.fetchPhotos(stopId);
    return Success(_photos.where((p) => p.stopId == stopId).toList());
  }
}
