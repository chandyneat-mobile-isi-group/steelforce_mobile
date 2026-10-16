import 'dart:async';

import 'package:steelforce/core/error/exceptions.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/core/network/connectivity/network_info.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/data/local/visit_local_data_source.dart';
import 'package:steelforce/features/my_visits/data/models/check_in_record_model.dart';
import 'package:steelforce/features/my_visits/data/models/check_out_record_model.dart';
import 'package:steelforce/features/my_visits/data/models/visit_capture_models.dart';
import 'package:steelforce/features/my_visits/data/models/visit_check_models.dart';
import 'package:steelforce/features/my_visits/data/remote/visit_check_remote_data_source.dart';
import 'package:steelforce/features/my_visits/domain/entities/check_in_record.dart';
import 'package:steelforce/features/my_visits/domain/entities/check_out_record.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_collection.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_note.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_order_line.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_photo.dart';
import 'package:steelforce/features/my_visits/domain/entities/server_visit.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_return.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_send_result.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_stock_update.dart';
import 'package:steelforce/features/my_visits/domain/repositories/visit_repository.dart';

class VisitRepositoryImpl implements VisitRepository {
  const VisitRepositoryImpl(
    this._local, {
    VisitCheckRemoteDataSource? remote,
    NetworkInfo? network,
    AppLogger? logger,
    void Function()? onQueued,
    this.onlineWait = const Duration(seconds: 6),
  })  : _remote = remote,
        _network = network,
        _logger = logger,
        _onQueued = onQueued;

  final VisitLocalDataSource _local;

  /// Optional so the local-only construction sites (tests) still compile;
  /// without it every check-in and check-out simply waits for the batch push.
  final VisitCheckRemoteDataSource? _remote;
  final NetworkInfo? _network;
  final AppLogger? _logger;

  /// Wakes the sync engine. Called when a check-in or check-out could not be
  /// settled online, so the batch push picks it up as soon as it can.
  final void Function()? _onQueued;

  /// How long the rep waits for the server at check-in / check-out before the
  /// app moves on and leaves the row to the batch push. Kept under the check-in
  /// screen's 15 s watchdog. A request that lands later is harmless: the push
  /// re-sends the same id and the server answers with the same visit.
  final Duration onlineWait;

  @override
  ResultFuture<CheckInRecord> checkIn(CheckInRecord record) async {
    try {
      final model = CheckInRecordModel.fromEntity(record);
      await _local.insertCheckIn(model);
      return Success(model);
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
  }

  @override
  ResultFuture<CheckOutRecord> checkOut(CheckOutRecord record) async {
    try {
      final model = CheckOutRecordModel.fromEntity(record);
      await _local.insertCheckOut(model);
      return Success(model);
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
  }

  @override
  ResultFuture<String?> checkInIdForStop(String stopId) async {
    try {
      return Success((await _local.checkInForStop(stopId))?.id);
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
  }

  @override
  ResultFuture<VisitSendResult> sendCheckIn(CheckInRecord record) =>
      _send('check_in', record.id, () async {
        final remote = _remote!;
        final model = CheckInRecordModel.fromEntity(record);
        try {
          final visit = await remote.checkIn(model).timeout(onlineWait);
          await _local.markSynced(table: 'checkins', ids: [record.id]);
          return VisitSendResult(VisitSendStatus.sent, serverVisit: visit);
        } on ApiException catch (e) {
          final error = e.error;
          switch (error.code) {
            case VisitErrorCodes.alreadyCheckedIn:
              // Another device (or an earlier attempt under another id) opened
              // this visit. Take the server's; the check-out will close it.
              final serverId = error.details?['visitId'];
              if (serverId is! String || serverId.isEmpty) rethrow;
              await _local.adoptServerCheckIn(record.id, serverId);
              return VisitSendResult(VisitSendStatus.sent,
                  serverVisit: _detailsVisit(error));
            case VisitErrorCodes.alreadyCompleted:
              await _local.deleteCheckIn(record.id);
              return VisitSendResult(VisitSendStatus.alreadyVisited,
                  serverVisit: _detailsVisit(error));
            case VisitErrorCodes.stopNotFound:
              await _local.deleteCheckIn(record.id);
              return const VisitSendResult(VisitSendStatus.notOnRoute);
          }
          rethrow;
        }
      });

  @override
  ResultFuture<VisitSendResult> sendCheckOut(CheckOutRecord record) =>
      _send('check_out', record.id, () async {
        final remote = _remote!;
        // A check-out never goes ahead of its check-in. If the check-in is
        // still on the device, the batch push sends both, in order.
        final checkIn = await _local.checkInForStop(record.stopId);
        final pendingCheckIns = await _local.fetchPendingCheckIns();
        if (checkIn != null && pendingCheckIns.any((c) => c.id == checkIn.id)) {
          return const VisitSendResult.queued();
        }

        final model = CheckOutRecordModel.fromEntity(record);
        try {
          final visit = await remote.checkOut(model).timeout(onlineWait);
          await _local.markSynced(table: 'checkouts', ids: [record.id]);
          return VisitSendResult(VisitSendStatus.sent, serverVisit: visit);
        } on ApiException catch (e) {
          final error = e.error;
          switch (error.code) {
            case VisitErrorCodes.alreadyCheckedOut:
              // Closed already, by another check-out. The server's stands.
              await _local.markSynced(table: 'checkouts', ids: [record.id]);
              return VisitSendResult(VisitSendStatus.sent,
                  serverVisit: _detailsVisit(error));
            case VisitErrorCodes.stopNotFound:
              await _local.deleteCheckOut(record.id);
              return const VisitSendResult(VisitSendStatus.notOnRoute);
          }
          rethrow;
        }
      });

  /// The shared shape of both sends: offline or unwired → queued; any answer
  /// that is not definite → queued, and the sync engine is woken to retry
  /// through the batch push, which is lenient where these endpoints are strict.
  Future<Result<VisitSendResult>> _send(
    String what,
    String id,
    Future<VisitSendResult> Function() attempt,
  ) async {
    final network = _network;
    if (_remote == null || network == null || !await network.isConnected) {
      _onQueued?.call();
      return const Success(VisitSendResult.queued());
    }
    try {
      final result = await attempt();
      if (result.status == VisitSendStatus.queued) _onQueued?.call();
      _logger
          ?.info('visit.$what.online', fields: {'result': result.status.name});
      return Success(result);
    } on ApiException catch (e) {
      // Codes and statuses only — never the body (it carries coordinates).
      _logger?.warning('visit.$what.queued', fields: {
        'code': e.error.code,
        'status': e.error.statusCode,
      });
    } on TimeoutException {
      _logger?.info('visit.$what.queued', fields: {'reason': 'timeout'});
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
    _onQueued?.call();
    return const Success(VisitSendResult.queued());
  }

  static ServerVisit? _detailsVisit(ApiError error) {
    final details = error.details;
    return details == null ? null : serverVisitFromJson(details);
  }

  @override
  ResultFuture<void> addOrderLine(VisitOrderLine line) async {
    try {
      await _local.insertOrderLine(VisitOrderLineModel(
        id: line.id,
        stopId: line.stopId,
        productId: line.productId,
        productName: line.productName,
        quantity: line.quantity,
        unit: line.unit,
        unitPrice: line.unitPrice,
      ));
      return const Success(null);
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
  }

  @override
  ResultFuture<void> addStockUpdate(VisitStockUpdate update) async {
    try {
      await _local.insertStockUpdate(VisitStockUpdateModel(
        id: update.id,
        stopId: update.stopId,
        depotId: update.depotId,
        productId: update.productId,
        productName: update.productName,
        stockLevel: update.stockLevel,
        notes: update.notes,
      ));
      return const Success(null);
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
  }

  @override
  ResultFuture<void> addReturn(VisitReturn returnItem) async {
    try {
      await _local.insertReturn(VisitReturnModel(
        id: returnItem.id,
        stopId: returnItem.stopId,
        productId: returnItem.productId,
        productName: returnItem.productName,
        quantity: returnItem.quantity,
        reason: returnItem.reason,
      ));
      return const Success(null);
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
  }

  @override
  ResultFuture<void> addCollection(VisitCollection collection) async {
    try {
      await _local.insertCollection(VisitCollectionModel(
        id: collection.id,
        stopId: collection.stopId,
        amount: collection.amount,
        method: collection.method,
        reference: collection.reference,
        notes: collection.notes,
      ));
      return const Success(null);
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
  }

  @override
  ResultFuture<void> addNote(VisitNote note) async {
    try {
      await _local.insertNote(VisitNoteModel(
        id: note.id,
        stopId: note.stopId,
        type: note.type,
        text: note.text,
        createdAt: note.createdAt,
      ));
      return const Success(null);
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
  }

  @override
  ResultFuture<void> addPhoto(VisitPhoto photo) async {
    try {
      await _local.insertPhoto(VisitPhotoModel(
        id: photo.id,
        stopId: photo.stopId,
        url: photo.url,
        caption: photo.caption,
        takenAt: photo.takenAt,
        isSignature: photo.isSignature,
      ));
      return const Success(null);
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
  }

  @override
  ResultFuture<List<VisitOrderLine>> fetchOrderLines(String stopId) async {
    try {
      return Success(await _local.fetchOrderLines(stopId));
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
  }

  @override
  ResultFuture<List<VisitStockUpdate>> fetchStockUpdates(String stopId) async {
    try {
      return Success(await _local.fetchStockUpdates(stopId));
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
  }

  @override
  ResultFuture<List<VisitReturn>> fetchReturns(String stopId) async {
    try {
      return Success(await _local.fetchReturns(stopId));
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
  }

  @override
  ResultFuture<List<VisitCollection>> fetchCollections(String stopId) async {
    try {
      return Success(await _local.fetchCollections(stopId));
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
  }

  @override
  ResultFuture<List<VisitNote>> fetchNotes(String stopId) async {
    try {
      return Success(await _local.fetchNotes(stopId));
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
  }

  @override
  ResultFuture<List<VisitPhoto>> fetchPhotos(String stopId) async {
    try {
      return Success(await _local.fetchPhotos(stopId));
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
  }
}

/// The visit error codes the live endpoints answer with
/// (`check-in-check-out-mobile.md` §4–§5).
abstract final class VisitErrorCodes {
  static const alreadyCheckedIn = 'Visit.AlreadyCheckedIn';
  static const alreadyCompleted = 'Visit.AlreadyCompleted';
  static const alreadyCheckedOut = 'Visit.AlreadyCheckedOut';
  static const stopNotFound = 'Visit.StopNotFound';
}
