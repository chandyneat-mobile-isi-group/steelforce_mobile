import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/features/depots/domain/entities/depot.dart';
import 'package:steelforce/features/depots/domain/usecases/browse_depots.dart';
import 'package:steelforce/features/depots/domain/usecases/depot_params.dart';

sealed class SupplyingDepotPickerState extends Equatable {
  const SupplyingDepotPickerState(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

class SupplyingDepotPickerLoading extends SupplyingDepotPickerState {
  const SupplyingDepotPickerLoading(super.query);
}

class SupplyingDepotPickerLoaded extends SupplyingDepotPickerState {
  const SupplyingDepotPickerLoaded(super.query, this.depots);

  final List<Depot> depots;

  @override
  List<Object?> get props => [query, depots];
}

class SupplyingDepotPickerEmpty extends SupplyingDepotPickerState {
  const SupplyingDepotPickerEmpty(super.query);
}

class SupplyingDepotPickerFailure extends SupplyingDepotPickerState {
  const SupplyingDepotPickerFailure(super.query, this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [query, failure];
}

/// The depots a Non-BP depot may name as its suppliers: the rep's own synced
/// depots that SAP has numbered, since the server takes SAP customer numbers
/// only. Read from the local book, so it works offline.
class SupplyingDepotPickerCubit extends Cubit<SupplyingDepotPickerState> {
  SupplyingDepotPickerCubit(this._browse)
      : super(const SupplyingDepotPickerLoading(''));

  final BrowseDepots _browse;

  static const _pageSize = 100;

  /// Bumped per search, so a slow earlier answer never overwrites a newer one.
  int _request = 0;

  Future<void> search(String query) async {
    final request = ++_request;
    final trimmed = query.trim();
    emit(SupplyingDepotPickerLoading(trimmed));
    final result = await _browse(
      BrowseDepotsParams(page: 1, pageSize: _pageSize, query: trimmed),
    );
    if (isClosed || request != _request) return;
    result.when(
      success: (page) {
        final depots = page.items.where(_hasSapNumber).toList();
        emit(depots.isEmpty
            ? SupplyingDepotPickerEmpty(trimmed)
            : SupplyingDepotPickerLoaded(trimmed, depots));
      },
      failure: (failure) => emit(SupplyingDepotPickerFailure(trimmed, failure)),
    );
  }

  static bool _hasSapNumber(Depot d) =>
      d.sapDepotId?.trim().isNotEmpty ?? false;
}
