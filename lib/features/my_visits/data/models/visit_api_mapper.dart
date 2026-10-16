import 'package:steelforce/core/network/api/api_envelope.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/data/models/check_in_record_model.dart';
import 'package:steelforce/features/my_visits/data/models/check_out_record_model.dart';
import 'package:steelforce/features/my_visits/data/models/visit_capture_models.dart';
import 'package:steelforce/features/my_visits/data/remote/visit_push_batch.dart';
import 'package:steelforce/features/my_visits/domain/entities/check_out_outcome.dart';

/// Wire serialisation for the visit-capture push (`POST /mobile/visits/push`).
///
/// **This is a second, deliberately separate encoding of the same models.**
/// Every capture model already has a `toRow()` — but that is the *Drift* shape:
/// snake_case column names, booleans as `0`/`1`, timestamps as bare
/// `toIso8601String()`. The API shape is camelCase, real JSON booleans, and
/// offset-bearing timestamps. Reusing `toRow()` on the wire would send
/// `stop_id` and `is_mocked: 1` to an endpoint documented to read `stopId` and
/// `isMocked: true`, so the two encodings stay apart on purpose.
///
/// Field names here are a hard contract (`docs/feature/my-visits/api.md` §7): the
/// backend spec was derived *from these models*, so renaming one silently
/// breaks the endpoint rather than failing a compile.
///
/// Enums go out as their exact Dart `name` — `low`, `bankTransfer`,
/// `competitorActivity` — never as integers and never as the SAP short codes
/// in `StockLevelSapMapping`, which belong to a different transport.
extension VisitPushBatchApiJson on VisitPushBatch {
  /// The push request body.
  ///
  /// **Photos are absent by design — see [photosAreBlocked].** Every other
  /// list is sent whole; empty lists are still emitted so the payload shape is
  /// stable and the server never has to distinguish "no rows" from "key
  /// missing".
  DataMap toPushJson() => {
        'checkIns': [for (final r in checkIns) r.toApiJson()],
        'checkOuts': [for (final r in checkOuts) r.toApiJson()],
        'orderLines': [for (final r in orderLines) r.toApiJson()],
        'stockUpdates': [for (final r in stockUpdates) r.toApiJson()],
        'returns': [for (final r in returns) r.toApiJson()],
        'collections': [for (final r in collections) r.toApiJson()],
        'notes': [for (final r in notes) r.toApiJson()],
        // Intentionally always empty. Not an oversight — see below.
        'photos': const <DataMap>[],
      };

  /// True when this batch holds nothing the push endpoint can currently take.
  ///
  /// Distinct from [VisitPushBatch.isEmpty], which counts photos. A batch of
  /// nothing but photos is *not* empty on the device but is un-pushable, and
  /// posting it would burn a round trip to send eight empty arrays.
  bool get hasNothingSendable =>
      checkIns.isEmpty &&
      checkOuts.isEmpty &&
      orderLines.isEmpty &&
      stockUpdates.isEmpty &&
      returns.isEmpty &&
      collections.isEmpty &&
      notes.isEmpty;

  /// Photo ids held back from this push.
  ///
  /// **OPEN-1 (`docs/feature/my-visits/api.md` §10) — blocking for photos.**
  /// `VisitPhoto.url` is a path on the *device*; binary cannot travel inside
  /// the JSON batch, and no upload endpoint exists yet. Sending the local path
  /// as if it were a server URL would have the backend accept the row, the
  /// client mark it synced, and the image be lost the moment the app's
  /// sandbox is cleared — a silent data-loss bug that looks like success.
  ///
  /// So photos stay pending on the device. Because the server never sees these
  /// ids, it cannot return them in `acceptedIds`, and
  /// `VisitSyncRepositoryImpl` therefore leaves them `pending` with no special
  /// case — they drain by themselves once a real upload path exists.
  ///
  /// TODO(OPEN-1): once the backend decides between a multipart
  /// `POST /mobile/visits/photos` and pre-signed upload URLs, upload the
  /// binary first, rewrite `url` to the returned server URL, then include the
  /// rows here.
  List<String> get photosAreBlocked => [for (final p in photos) p.id];
}

extension CheckInRecordApiJson on CheckInRecordModel {
  DataMap toApiJson() => {
        'id': id,
        'stopId': stopId,
        // The device's own clock, never rewritten to server time (§8.4). The
        // server stores this alongside its receipt time; only the receipt time
        // is authoritative for server-side processing.
        'timestamp': formatIsoOffset(timestamp),
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracyMeters,
        // Geofence *evidence*, not a verdict (§8.2). The server decides
        // whether the visit qualifies; the client only reports what it saw.
        'distanceFromDepot': distanceFromDepotMeters,
        // A fraud signal, not a reason to withhold the row — a suppressed
        // mock-location check-in is exactly the one worth investigating.
        'isMocked': isMocked,
        // Omitted entirely on an ordinary check-in rather than sent as null.
        // The field is optional on the wire (api.md §7.3), and the server reads
        // its absence as "nobody was asked to explain this row" — which is a
        // different fact from an override whose reason went missing.
        if (overrideReason != null) 'overrideReason': overrideReason,
        if (routeId != null) 'routeId': routeId,
      };
}

extension CheckOutRecordApiJson on CheckOutRecordModel {
  DataMap toApiJson() => {
        'id': id,
        'stopId': stopId,
        'timestamp': formatIsoOffset(timestamp),
        'latitude': latitude,
        'longitude': longitude,
        'durationMinutes': durationMinutes,
        'visitSummary': visitSummary,
        // The same body serves `POST /visits/check-outs` and a `/push` row
        // (check-in-check-out-mobile.md §5, §9). A check-out queued before
        // outcomes existed leaves these out, and the server stores `unknown`.
        if (checkInId != null) 'checkInId': checkInId,
        if (outcome != null) 'outcome': outcome!.name,
        if (outcome == CheckOutOutcome.withOrder)
          'orders': [for (final o in orders) o.toJson()],
        if (outcome == CheckOutOutcome.withoutOrder) ...{
          'noOrderReason': noOrderReason,
          if (noOrderNote != null && noOrderNote!.trim().isNotEmpty)
            'noOrderNote': noOrderNote!.trim(),
        },
      };
}

extension VisitOrderLineApiJson on VisitOrderLineModel {
  DataMap toApiJson() => {
        'id': id,
        'stopId': stopId,
        'productId': productId,
        'productName': productName,
        'quantity': quantity,
        'unit': unit,
        'unitPrice': unitPrice,
      };
}

extension VisitStockUpdateApiJson on VisitStockUpdateModel {
  /// Exactly one of `stopId`/`depotId` is set — a count taken during a visit
  /// carries `stopId`, a standalone depot audit carries `depotId`.
  ///
  /// **The unset one is omitted, not sent as `null`.** It used to be emitted
  /// explicitly, on the reasoning that a visible null "keeps the distinction
  /// legible server-side". It does the opposite: the endpoint's `StockUpdate`
  /// DTO binds `DepotId` as a required value, so an explicit null fails
  /// ASP.NET model validation before any handler runs — and because that
  /// validation rejects the *envelope*, one such row 400s the entire push.
  /// Observed as `General.Validation` with `invalidFields=[StockUpdates[N].DepotId]`
  /// for every row in the batch, blocking check-ins and notes that had nothing
  /// wrong with them.
  ///
  /// Omission is also what the exactly-one invariant on [VisitStockUpdate]
  /// actually means. A key that is absent says "this row is not that kind";
  /// a key present and null says "this row is that kind, and I lost the id".
  DataMap toApiJson() => {
        'id': id,
        if (stopId != null) 'stopId': stopId,
        if (depotId != null) 'depotId': depotId,
        'productId': productId,
        'productName': productName,
        'stockLevel': stockLevel.storageName,
        'notes': notes,
      };
}

extension VisitReturnApiJson on VisitReturnModel {
  DataMap toApiJson() => {
        'id': id,
        'stopId': stopId,
        'productId': productId,
        'productName': productName,
        'quantity': quantity,
        'reason': reason,
      };
}

extension VisitCollectionApiJson on VisitCollectionModel {
  DataMap toApiJson() => {
        'id': id,
        'stopId': stopId,
        'amount': amount,
        'method': method.name,
        'reference': reference,
        'notes': notes,
      };
}

extension VisitNoteApiJson on VisitNoteModel {
  DataMap toApiJson() => {
        'id': id,
        'stopId': stopId,
        'type': type.name,
        'text': text,
        'createdAt': formatIsoOffset(createdAt),
      };
}
