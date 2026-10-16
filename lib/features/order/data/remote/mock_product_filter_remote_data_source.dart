import 'package:steelforce/core/error/exceptions.dart';
import 'package:steelforce/core/utils/mock_latency.dart';
import 'package:steelforce/features/order/data/mock/isi_filter_schema_data.dart';
import 'package:steelforce/features/order/data/models/category_filter_schema_model.dart';
import 'package:steelforce/features/order/data/remote/product_filter_remote_data_source.dart';

/// Stands in for the SAP endpoint that publishes the configurator layout.
///
/// Shaped like the real thing on purpose: one round trip, JSON in the wire
/// format, parsed through the same models a Dio implementation would use. The
/// response is small and changes rarely, so it is fetched once per app session
/// and held — the same caching a real client would apply.
class MockProductFilterRemoteDataSource
    implements ProductFilterRemoteDataSource {
  MockProductFilterRemoteDataSource();

  List<CategoryFilterSchemaModel>? _cache;

  @override
  Future<List<CategoryFilterSchemaModel>> fetchFilterSchemas() async {
    final cached = _cache;
    if (cached != null) return cached;
    try {
      await MockLatency.tick();
      return _cache = IsiFilterSchemaData.schemas()
          .map(CategoryFilterSchemaModel.fromJson)
          .toList();
    } catch (e) {
      throw ServerException(message: 'Failed to load filter schemas: $e');
    }
  }
}
