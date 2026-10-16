import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/domain/entities/check_in_record.dart';
import 'package:steelforce/features/my_visits/domain/entities/check_out_record.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_collection.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_send_result.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_note.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_order_line.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_photo.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_return.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_stock_update.dart';

abstract interface class VisitRepository {
  ResultFuture<CheckInRecord> checkIn(CheckInRecord record);
  ResultFuture<CheckOutRecord> checkOut(CheckOutRecord record);

  /// Offers a check-in already saved by [checkIn] to the server now
  /// (`POST /visits/check-ins`). Never fails the check-in: anything short of
  /// a definite answer leaves it queued for the next sync.
  ResultFuture<VisitSendResult> sendCheckIn(CheckInRecord record);

  /// Same for a saved check-out. Held back (queued) while the stop's check-in
  /// has not reached the server, so a check-out never arrives first.
  ResultFuture<VisitSendResult> sendCheckOut(CheckOutRecord record);

  /// The id of the check-in saved for [stopId] — the visit a check-out closes.
  ResultFuture<String?> checkInIdForStop(String stopId);

  ResultFuture<void> addOrderLine(VisitOrderLine line);
  ResultFuture<void> addStockUpdate(VisitStockUpdate update);
  ResultFuture<void> addReturn(VisitReturn returnItem);
  ResultFuture<void> addCollection(VisitCollection collection);
  ResultFuture<void> addNote(VisitNote note);
  ResultFuture<void> addPhoto(VisitPhoto photo);

  ResultFuture<List<VisitOrderLine>> fetchOrderLines(String stopId);
  ResultFuture<List<VisitStockUpdate>> fetchStockUpdates(String stopId);
  ResultFuture<List<VisitReturn>> fetchReturns(String stopId);
  ResultFuture<List<VisitCollection>> fetchCollections(String stopId);
  ResultFuture<List<VisitNote>> fetchNotes(String stopId);
  ResultFuture<List<VisitPhoto>> fetchPhotos(String stopId);
}
