import 'package:steelforce/features/order/data/models/category_filter_schema_model.dart';

/// SAP-shaped source for the *filter hierarchy* (not its values).
///
/// Mirrors a single read endpoint — `GET /catalog/filter-schema` — returning
/// the configurator layout merchandising maintains in SAP. A Dio-backed
/// implementation is a drop-in replacement behind this interface; nothing above
/// [ProductFilterRepository] changes.
abstract interface class ProductFilterRemoteDataSource {
  /// Every published schema, keyed by category id. Small (kilobytes) and
  /// cacheable — this is configuration, not catalog data.
  Future<List<CategoryFilterSchemaModel>> fetchFilterSchemas();
}
