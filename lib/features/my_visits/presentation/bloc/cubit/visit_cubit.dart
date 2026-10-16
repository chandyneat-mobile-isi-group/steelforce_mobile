import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_collection.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_note.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_order_line.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_photo.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_return.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_stock_update.dart';
import 'package:steelforce/features/my_visits/domain/usecases/add_collection.dart';
import 'package:steelforce/features/my_visits/domain/usecases/add_order_line.dart';
import 'package:steelforce/features/my_visits/domain/usecases/add_return.dart';
import 'package:steelforce/features/my_visits/domain/usecases/add_stock_update.dart';
import 'package:steelforce/features/my_visits/domain/usecases/add_visit_note.dart';
import 'package:steelforce/features/my_visits/domain/usecases/add_visit_photo.dart';
import 'package:steelforce/features/my_visits/domain/usecases/fetch_visit_data.dart';
import 'package:steelforce/features/my_visits/domain/usecases/routes_params.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/state/visit_state.dart';

/// All offline capture for the currently checked-in stop: orders, stock
/// updates, returns, collections, notes, and photos/signature.
class VisitCubit extends Cubit<VisitState> {
  VisitCubit({
    required FetchVisitData fetchVisitData,
    required AddOrderLine addOrderLine,
    required AddStockUpdate addStockUpdate,
    required AddReturn addReturn,
    required AddCollection addCollection,
    required AddVisitNote addVisitNote,
    required AddVisitPhoto addVisitPhoto,
  })  : _fetchVisitData = fetchVisitData,
        _addOrderLine = addOrderLine,
        _addStockUpdate = addStockUpdate,
        _addReturn = addReturn,
        _addCollection = addCollection,
        _addVisitNote = addVisitNote,
        _addVisitPhoto = addVisitPhoto,
        super(const VisitLoading());

  final FetchVisitData _fetchVisitData;
  final AddOrderLine _addOrderLine;
  final AddStockUpdate _addStockUpdate;
  final AddReturn _addReturn;
  final AddCollection _addCollection;
  final AddVisitNote _addVisitNote;
  final AddVisitPhoto _addVisitPhoto;

  Future<void> load(String stopId) async {
    emit(const VisitLoading());
    final result = await _fetchVisitData(StopIdParams(stopId));
    result.when(
      success: (data) => emit(VisitLoaded(data)),
      failure: (f) => emit(VisitError(f.message)),
    );
  }

  Future<void> addOrderLine(VisitOrderLine line) async {
    final current = state;
    if (current is! VisitLoaded) return;
    emit(VisitLoaded(
        _withOrderLines(current.data, [...current.data.orderLines, line])));
    await _addOrderLine(line);
  }

  Future<void> addStockUpdate(VisitStockUpdate update) async {
    final current = state;
    if (current is! VisitLoaded) return;
    emit(VisitLoaded(_withStockUpdates(
        current.data, [...current.data.stockUpdates, update])));
    await _addStockUpdate(update);
  }

  Future<void> addReturn(VisitReturn returnItem) async {
    final current = state;
    if (current is! VisitLoaded) return;
    emit(VisitLoaded(
        _withReturns(current.data, [...current.data.returns, returnItem])));
    await _addReturn(returnItem);
  }

  Future<void> addCollection(VisitCollection collection) async {
    final current = state;
    if (current is! VisitLoaded) return;
    emit(VisitLoaded(_withCollections(
        current.data, [...current.data.collections, collection])));
    await _addCollection(collection);
  }

  Future<void> addNote(VisitNote note) async {
    final current = state;
    if (current is! VisitLoaded) return;
    emit(VisitLoaded(_withNotes(current.data, [note, ...current.data.notes])));
    await _addVisitNote(note);
  }

  Future<void> addPhoto(VisitPhoto photo) async {
    final current = state;
    if (current is! VisitLoaded) return;
    emit(VisitLoaded(
        _withPhotos(current.data, [photo, ...current.data.photos])));
    await _addVisitPhoto(photo);
  }

  VisitData _withOrderLines(VisitData d, List<VisitOrderLine> v) => VisitData(
      orderLines: v,
      stockUpdates: d.stockUpdates,
      returns: d.returns,
      collections: d.collections,
      notes: d.notes,
      photos: d.photos);
  VisitData _withStockUpdates(VisitData d, List<VisitStockUpdate> v) =>
      VisitData(
          orderLines: d.orderLines,
          stockUpdates: v,
          returns: d.returns,
          collections: d.collections,
          notes: d.notes,
          photos: d.photos);
  VisitData _withReturns(VisitData d, List<VisitReturn> v) => VisitData(
      orderLines: d.orderLines,
      stockUpdates: d.stockUpdates,
      returns: v,
      collections: d.collections,
      notes: d.notes,
      photos: d.photos);
  VisitData _withCollections(VisitData d, List<VisitCollection> v) => VisitData(
      orderLines: d.orderLines,
      stockUpdates: d.stockUpdates,
      returns: d.returns,
      collections: v,
      notes: d.notes,
      photos: d.photos);
  VisitData _withNotes(VisitData d, List<VisitNote> v) => VisitData(
      orderLines: d.orderLines,
      stockUpdates: d.stockUpdates,
      returns: d.returns,
      collections: d.collections,
      notes: v,
      photos: d.photos);
  VisitData _withPhotos(VisitData d, List<VisitPhoto> v) => VisitData(
      orderLines: d.orderLines,
      stockUpdates: d.stockUpdates,
      returns: d.returns,
      collections: d.collections,
      notes: d.notes,
      photos: v);
}
