import 'package:steelforce/core/database/drift/daos/order_dao.dart';
import 'package:steelforce/core/error/exceptions.dart';
import 'package:steelforce/core/utils/mock_latency.dart';
import 'package:steelforce/core/utils/typedefs.dart';

abstract interface class QuotationLocalDataSource {
  Future<void> insertQuotation(DataMap row);
  Future<void> updateQuotation(DataMap row);
  Future<void> deleteQuotation(String id);
  Future<DataMap?> getById(String id);
  Future<List<DataMap>> fetchAll();
}

/// Drift-backed quotations store (**T1.5b**), replacing the plaintext
/// `catalog.db` implementation.
///
/// The interface, the `DataMap` row shape, and every [CacheException] message
/// are unchanged — the repository above this class cannot tell that the store
/// moved. That is the whole acceptance criterion for the cutover.
class QuotationLocalDataSourceImpl implements QuotationLocalDataSource {
  const QuotationLocalDataSourceImpl(this._dao);
  final QuotationDao _dao;

  @override
  Future<void> insertQuotation(DataMap row) async {
    try {
      await _dao.upsert(row);
    } catch (e) {
      throw CacheException(message: 'Failed to save quotation: $e');
    }
  }

  @override
  Future<void> updateQuotation(DataMap row) async {
    try {
      await _dao.updateRow(row);
    } catch (e) {
      throw CacheException(message: 'Failed to update quotation: $e');
    }
  }

  @override
  Future<void> deleteQuotation(String id) async {
    try {
      await _dao.deleteById(id);
    } catch (e) {
      throw CacheException(message: 'Failed to delete quotation $id: $e');
    }
  }

  @override
  Future<DataMap?> getById(String id) async {
    try {
      return await _dao.getById(id);
    } catch (e) {
      throw CacheException(message: 'Failed to load quotation $id: $e');
    }
  }

  @override
  Future<List<DataMap>> fetchAll() async {
    try {
      await MockLatency.tick(); // simulate a slow quotations API
      return await _dao.fetchAll();
    } catch (e) {
      throw CacheException(message: 'Failed to load quotations: $e');
    }
  }
}
