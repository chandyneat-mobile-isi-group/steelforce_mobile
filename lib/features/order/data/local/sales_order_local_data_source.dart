import 'package:steelforce/core/database/drift/daos/order_dao.dart';
import 'package:steelforce/core/error/exceptions.dart';
import 'package:steelforce/core/utils/mock_latency.dart';
import 'package:steelforce/core/utils/typedefs.dart';

abstract interface class SalesOrderLocalDataSource {
  Future<void> insertSalesOrder(DataMap row);
  Future<DataMap?> getById(String id);
  Future<List<DataMap>> fetchAll();
}

/// Drift-backed sales-order store (**T1.5b**), replacing the plaintext
/// `catalog.db` implementation. Interface and row shape unchanged.
class SalesOrderLocalDataSourceImpl implements SalesOrderLocalDataSource {
  const SalesOrderLocalDataSourceImpl(this._dao);
  final SalesOrderDao _dao;

  @override
  Future<void> insertSalesOrder(DataMap row) async {
    try {
      await _dao.upsert(row);
    } catch (e) {
      throw CacheException(message: 'Failed to save sales order: $e');
    }
  }

  @override
  Future<DataMap?> getById(String id) async {
    try {
      return await _dao.getById(id);
    } catch (e) {
      throw CacheException(message: 'Failed to load sales order $id: $e');
    }
  }

  @override
  Future<List<DataMap>> fetchAll() async {
    try {
      await MockLatency.tick(); // simulate a slow sales-orders API
      return await _dao.fetchAll();
    } catch (e) {
      throw CacheException(message: 'Failed to load sales orders: $e');
    }
  }
}
