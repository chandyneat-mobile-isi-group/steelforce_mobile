import 'package:steelforce/features/order/data/models/category_model.dart';
import 'package:steelforce/features/order/data/remote/remote_sync_page.dart';
import 'package:steelforce/features/order/domain/entities/sync_scope.dart';

/// SAP-shaped sync source. [MockProductRemoteDataSource] is the only
/// implementation today, backed by the generated `assets/mock/products.json`
/// — a real Dio-backed SAP implementation (following
/// `AuthRemoteDataSource`'s pattern: resolve `sl<Dio>()`, map `DioException`s
/// to typed exceptions) is a drop-in replacement behind this same interface,
/// with zero changes needed above [SyncRepository].
abstract interface class ProductRemoteDataSource {
  Future<List<CategoryModel>> fetchCategories();

  /// Full first-time pull, scoped and paged — never returns the whole catalog
  /// in one call.
  Future<RemoteSyncPage> fetchInitial({
    required SyncScope scope,
    required int page,
    required int pageSize,
  });

  /// Only what changed (products, prices, stock, deletions) since [since].
  Future<RemoteDeltaPage> fetchDelta(
      {required SyncScope scope, required DateTime since});
}
