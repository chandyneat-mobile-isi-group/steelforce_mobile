import 'package:equatable/equatable.dart';
import 'package:steelforce/features/order/domain/entities/product_filter.dart';

sealed class CatalogEvent extends Equatable {
  const CatalogEvent();
  @override
  List<Object?> get props => [];
}

final class CatalogLoadRequested extends CatalogEvent {
  const CatalogLoadRequested();
}

final class CatalogRefreshRequested extends CatalogEvent {
  const CatalogRefreshRequested();
}

final class CatalogLoadMoreRequested extends CatalogEvent {
  const CatalogLoadMoreRequested();
}

final class CatalogSearchChanged extends CatalogEvent {
  const CatalogSearchChanged(this.query);
  final String query;
  @override
  List<Object?> get props => [query];
}

final class CatalogFilterChanged extends CatalogEvent {
  const CatalogFilterChanged(this.filter);
  final ProductFilter filter;
  @override
  List<Object?> get props => [filter];
}

/// Seeds the catalog with a persisted [query] + [filter] pair atomically —
/// used when restoring the Product Filter screen so both dimensions apply in a
/// single query (rather than racing a search event against a filter event).
final class CatalogRestoreRequested extends CatalogEvent {
  const CatalogRestoreRequested({required this.query, required this.filter});
  final String query;
  final ProductFilter filter;
  @override
  List<Object?> get props => [query, filter];
}

/// Voice search: [query] is the on-device transcription of what the user said.
/// In production this maps to a Voice→Text + vector lookup; here it drives the
/// same local search so the flow is fully exercised offline.
final class CatalogVoiceSearchRequested extends CatalogEvent {
  const CatalogVoiceSearchRequested(this.query);
  final String query;
  @override
  List<Object?> get props => [query];
}

/// Image search: [query] is the keyword the visual-match pipeline resolved the
/// uploaded/captured product photo to (stand-in for a multi-modal embedding
/// endpoint), used to fetch matching product cards.
final class CatalogImageSearchRequested extends CatalogEvent {
  const CatalogImageSearchRequested(this.query);
  final String query;
  @override
  List<Object?> get props => [query];
}
