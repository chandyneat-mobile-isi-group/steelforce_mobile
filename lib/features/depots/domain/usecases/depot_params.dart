import 'package:equatable/equatable.dart';
import 'package:steelforce/features/depots/domain/entities/depot_activity.dart';
import 'package:steelforce/features/depots/domain/entities/depot_filter.dart';

class DepotIdParams extends Equatable {
  const DepotIdParams(this.depotId);
  final String depotId;
  @override
  List<Object?> get props => [depotId];
}

class BrowseDepotsParams extends Equatable {
  const BrowseDepotsParams({
    required this.page,
    required this.pageSize,
    this.query = '',
    this.filter = const DepotFilter(),
  });

  final int page;
  final int pageSize;
  final String query;
  final DepotFilter filter;

  @override
  List<Object?> get props => [page, pageSize, query, filter];
}

class AddDepotNoteParams extends Equatable {
  const AddDepotNoteParams({required this.depotId, required this.body});
  final String depotId;
  final String body;
  @override
  List<Object?> get props => [depotId, body];
}

class AddDepotActivityParams extends Equatable {
  const AddDepotActivityParams(this.activity);
  final DepotActivity activity;
  @override
  List<Object?> get props => [activity];
}
