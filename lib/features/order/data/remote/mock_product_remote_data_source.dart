import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;
import 'package:steelforce/core/error/exceptions.dart';
import 'package:steelforce/features/order/data/mock/isi_demo_catalog.dart';
import 'package:steelforce/features/order/data/mock/mock_product_data.dart';
import 'package:steelforce/features/order/data/models/category_model.dart';
import 'package:steelforce/features/order/data/models/product_model.dart';
import 'package:steelforce/features/order/data/remote/product_remote_data_source.dart';
import 'package:steelforce/features/order/data/remote/remote_sync_page.dart';
import 'package:steelforce/features/order/domain/entities/product_pricing.dart';
import 'package:steelforce/features/order/domain/entities/sync_scope.dart';

/// Simulates an SAP catalog feed: loads the generated
/// `assets/mock/products.json` once (falling back to generating it in-memory
/// if the asset is ever missing), then serves scoped/paged initial syncs and
/// deterministic delta syncs from it — never the network, since this is a
/// demo stand-in, but shaped exactly like a real paginated REST source would
/// be so swapping in a Dio-backed implementation later is mechanical.
class MockProductRemoteDataSource implements ProductRemoteDataSource {
  /// [remoteImages] false blanks every row's `imageUrl`: the bundled rows
  /// point at an internet placeholder service, and a demo build must make no
  /// request at all.
  MockProductRemoteDataSource({bool remoteImages = true})
      : _remoteImages = remoteImages;

  final bool _remoteImages;

  List<ProductModel>? _products;
  List<CategoryModel>? _categories;

  Future<void> _ensureLoaded() async {
    if (_products != null) return;
    try {
      final raw = await rootBundle.loadString('assets/mock/products.json');
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      _products = _parseProducts(decoded['products'] as List);
      _categories = _parseCategories(decoded['categories'] as List);
    } catch (_) {
      final generated = MockProductData.generate();
      _products = _parseProducts(generated['products'] as List);
      _categories = _parseCategories(generated['categories'] as List);
    }
    _mergeIsiDemoLines();
  }

  List<ProductModel> _parseProducts(List raw) => raw
      .map((e) => ProductModel.fromJson(_remoteImages
          ? e as Map<String, dynamic>
          : {...e as Map<String, dynamic>, 'imageUrl': ''}))
      .toList();

  List<CategoryModel> _parseCategories(List raw) => raw
      .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
      .toList();

  /// Folds the hand-written ISI demo lines into whatever the feed returned.
  ///
  /// Done here rather than only inside [MockProductData] so the committed
  /// `assets/mock/products.json` — 20 MB, generated before these lines existed —
  /// doesn't have to be regenerated for the guided configurator to have data.
  /// Ids are stable and prefixed, so re-running the generator and re-merging
  /// converge on the same rows rather than duplicating them.
  void _mergeIsiDemoLines() {
    final existingProducts = _products!.map((p) => p.id).toSet();
    _products!.addAll(
      _parseProducts(IsiDemoCatalog.products())
          .where((p) => !existingProducts.contains(p.id)),
    );

    final existingCategories = _categories!.map((c) => c.id).toSet();
    _categories!.insertAll(
      0,
      _parseCategories(IsiDemoCatalog.categories())
          .where((c) => !existingCategories.contains(c.id)),
    );
  }

  bool _inScope(ProductModel p, SyncScope scope) =>
      scope.matchesWarehouse(p.warehouseCode) || p.territory == scope.territory;

  @override
  Future<List<CategoryModel>> fetchCategories() async {
    try {
      await _ensureLoaded();
      return _categories!;
    } catch (e) {
      throw ServerException(message: 'Failed to load categories: $e');
    }
  }

  @override
  Future<RemoteSyncPage> fetchInitial({
    required SyncScope scope,
    required int page,
    required int pageSize,
  }) async {
    try {
      await _ensureLoaded();
      final scoped = _products!.where((p) => _inScope(p, scope)).toList();
      final start = page * pageSize;
      if (start >= scoped.length) {
        return const RemoteSyncPage(items: [], hasMore: false);
      }
      final end = min(start + pageSize, scoped.length);
      return RemoteSyncPage(
          items: scoped.sublist(start, end), hasMore: end < scoped.length);
    } catch (e) {
      throw ServerException(message: 'Initial sync failed: $e');
    }
  }

  @override
  Future<RemoteDeltaPage> fetchDelta(
      {required SyncScope scope, required DateTime since}) async {
    try {
      await _ensureLoaded();
      final scoped = _products!.where((p) => _inScope(p, scope)).toList();
      if (scoped.isEmpty) {
        return const RemoteDeltaPage(upserted: [], deletedIds: []);
      }

      // Deterministic per-call-time delta: reseeding on `since` means the
      // exact same call repeated for the same timestamp is reproducible,
      // while later calls (later `since`) surface a different slice — this
      // is what makes the delta path genuinely exercised in a demo, not
      // just a no-op after the first sync.
      final rand = Random(since.millisecondsSinceEpoch ~/ 1000);
      final changedCount = max(1, (scoped.length * 0.05).round());
      final deletedCount = max(0, (scoped.length * 0.01).round());
      scoped.shuffle(rand);

      final deleted = scoped.take(deletedCount).map((p) => p.id).toList();
      final changed = scoped.skip(deletedCount).take(changedCount).map((p) {
        final priceJitter = 0.9 + rand.nextDouble() * 0.2;
        final stockJitter = rand.nextInt(500);
        final standard = double.parse(
            (p.pricing.standardPrice * priceJitter).toStringAsFixed(2));
        return ProductModel(
          id: p.id,
          familyId: p.familyId,
          familyName: p.familyName,
          code: p.code,
          sku: p.sku,
          materialCode: p.materialCode,
          barcode: p.barcode,
          name: p.name,
          // A delta rebuilds the row from scratch, so every field it forgets
          // is silently *erased* — not left alone. These four are all
          // defaulted on the constructor (`nameKh = ''`, `color = ''`, …),
          // so omitting them compiled fine and quietly wiped the Khmer name
          // off ~5% of the catalog on every delta sync. That is a data-loss
          // bug, not a mock shortcut: it made a correctly-synced bilingual
          // catalog decay back to English-only the longer the app ran.
          nameKh: p.nameKh,
          color: p.color,
          specification: p.specification,
          createdAt: p.createdAt,
          description: p.description,
          categoryId: p.categoryId,
          subCategory: p.subCategory,
          brand: p.brand,
          grade: p.grade,
          material: p.material,
          size: p.size,
          diameter: p.diameter,
          thickness: p.thickness,
          length: p.length,
          width: p.width,
          height: p.height,
          weight: p.weight,
          unit: p.unit,
          warehouseCode: p.warehouseCode,
          territory: p.territory,
          businessUnit: p.businessUnit,
          imageUrl: p.imageUrl,
          isMto: p.isMto,
          status: p.status,
          updatedAt: DateTime.now(),
          pricing: ProductPricing(
            costPrice: p.pricing.costPrice,
            standardPrice: standard,
            wholesalePrice: double.parse((standard * 0.92).toStringAsFixed(2)),
            dealerPrice: double.parse((standard * 0.85).toStringAsFixed(2)),
            vipPrice: double.parse((standard * 0.80).toStringAsFixed(2)),
            creditPrice: double.parse((standard * 1.03).toStringAsFixed(2)),
            cashPrice: double.parse((standard * 0.97).toStringAsFixed(2)),
            currency: p.pricing.currency,
            promotionPrice: p.pricing.promotionPrice,
            promotionType: p.pricing.promotionType,
            promotionLabel: p.pricing.promotionLabel,
          ),
          stockQuantity: (p.stockQuantity + stockJitter).toDouble(),
          reservedQuantity: p.reservedQuantity,
          minStock: p.minStock,
          maxStock: p.maxStock,
        );
      }).toList();

      return RemoteDeltaPage(upserted: changed, deletedIds: deleted);
    } catch (e) {
      throw ServerException(message: 'Delta sync failed: $e');
    }
  }
}
