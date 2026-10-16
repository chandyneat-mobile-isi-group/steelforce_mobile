import 'package:equatable/equatable.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_collection.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_note.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_order_line.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_photo.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_return.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_stock_update.dart';
import 'package:steelforce/features/my_visits/domain/repositories/visit_repository.dart';
import 'package:steelforce/features/my_visits/domain/usecases/routes_params.dart';

class VisitData extends Equatable {
  const VisitData({
    required this.orderLines,
    required this.stockUpdates,
    required this.returns,
    required this.collections,
    required this.notes,
    required this.photos,
  });

  final List<VisitOrderLine> orderLines;
  final List<VisitStockUpdate> stockUpdates;
  final List<VisitReturn> returns;
  final List<VisitCollection> collections;
  final List<VisitNote> notes;
  final List<VisitPhoto> photos;

  @override
  List<Object?> get props =>
      [orderLines, stockUpdates, returns, collections, notes, photos];
}

/// Aggregates every capture-list read for a stop into one call, so
/// `VisitCubit` doesn't need six separate round trips (and six separate
/// usecase files) just to open the visit screen.
class FetchVisitData extends UseCase<VisitData, StopIdParams> {
  const FetchVisitData(this._repository);
  final VisitRepository _repository;

  @override
  ResultFuture<VisitData> call(StopIdParams params) async {
    final orderLines = await _repository.fetchOrderLines(params.stopId);
    final stockUpdates = await _repository.fetchStockUpdates(params.stopId);
    final returns = await _repository.fetchReturns(params.stopId);
    final collections = await _repository.fetchCollections(params.stopId);
    final notes = await _repository.fetchNotes(params.stopId);
    final photos = await _repository.fetchPhotos(params.stopId);

    Failure? firstFailure;
    T unwrap<T>(Result<T> r, T empty) => r.when(
        success: (v) => v,
        failure: (f) {
          firstFailure ??= f;
          return empty;
        });

    final data = VisitData(
      orderLines: unwrap(orderLines, const []),
      stockUpdates: unwrap(stockUpdates, const []),
      returns: unwrap(returns, const []),
      collections: unwrap(collections, const []),
      notes: unwrap(notes, const []),
      photos: unwrap(photos, const []),
    );

    return firstFailure == null ? Success(data) : Failed(firstFailure!);
  }
}
