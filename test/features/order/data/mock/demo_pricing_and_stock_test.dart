import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/demo/demo_network.dart';
import 'package:steelforce/core/demo/demo_seed.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/core/network/connectivity/network_info.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/features/order/data/mock/demo_material_book.dart';
import 'package:steelforce/features/order/data/mock/demo_material_selection_remote_data_source.dart';
import 'package:steelforce/features/order/data/mock/demo_pricing_remote_data_source.dart';
import 'package:steelforce/features/order/data/models/material_api_mapper.dart';
import 'package:steelforce/features/order/data/models/mobile_price_model.dart';
import 'package:steelforce/features/order/data/repositories/material_availability_repository_impl.dart';
import 'package:steelforce/features/order/data/repositories/pricing_repository_impl.dart';
import 'package:steelforce/features/order/domain/entities/material_availability.dart';
import 'package:steelforce/features/order/domain/entities/mobile_price.dart';

Matcher get _offline => throwsA(
    isA<ApiException>().having((e) => e.code, 'code', ApiErrorCodes.network));

class _Online implements NetworkInfo {
  @override
  Future<bool> get isConnected async => true;
}

void main() {
  late DemoNetwork network;
  late DemoMaterialBook book;

  setUp(() {
    network = DemoNetwork();
    book = DemoMaterialBook();
  });

  group('DemoPricingRemoteDataSource', () {
    test('prices demo-catalog materials at their catalog price', () async {
      final source = DemoPricingRemoteDataSource(network, book);
      final rows = await source.fetchPrices(
        depotId: DemoSeed.depots.first.id,
        materials: ['2400001018', '1400000891', '9999999999'],
      );
      final prices = rows.map(MobilePriceMapper.fromJson).toList();
      expect(prices.map((p) => p.material), ['2400001018', '1400000891']);
      expect(prices.first.price, 4.12);
      expect(prices.first.currency, 'USD');
      expect(prices.first.state, PricingState.loaded);
    });

    test('a material the book does not know resolves to "no price"', () async {
      final repo = PricingRepositoryImpl(
        remote: DemoPricingRemoteDataSource(network, book),
        network: _Online(),
      );
      final result = await repo.getPrices(
          depotId: DemoSeed.depots.first.id, materials: ['9999999999']);
      final prices = (result as Success<List<MobilePrice>>).data;
      expect(prices.single.errorKind, PricingErrorKind.noPrice);
    });

    test('offline → network error', () {
      network.setOnline(false);
      expect(
        DemoPricingRemoteDataSource(network, book)
            .fetchPrices(depotId: 'demo-depot-001', materials: ['2400001018']),
        _offline,
      );
    });
  });

  group('DemoMaterialSelectionRemoteDataSource', () {
    late DemoMaterialSelectionRemoteDataSource source;
    setUp(() => source = DemoMaterialSelectionRemoteDataSource(network, book));

    test('most materials are sellable; a few are out of stock', () async {
      final verdicts = await Future.wait([
        for (final m in DemoMaterialBook.isiMaterials)
          source.fetchStock(m.number).then(
              (json) => MaterialApiMapper.stockFrom(json, requested: m.number)),
      ]);
      final out = verdicts.where((v) => !v.isSellable).toList();
      expect(out, isNotEmpty);
      expect(out.length, lessThan(verdicts.length ~/ 4));
      expect(out.every((v) => v.band == StockBand.none), isTrue);
      expect(verdicts.every((v) => v.plants.length == 2), isTrue);
    });

    test('the availability repository reads a real verdict', () async {
      final repo = MaterialAvailabilityRepositoryImpl(
          remote: source, network: _Online());
      final result = await repo.checkAvailability('2400001018');
      final verdict = (result as Success<MaterialAvailability>).data;
      expect(verdict.material, '2400001018');
      expect(verdict.baseUnit, 'M');
    });

    test('unknown material → 404', () {
      expect(
          source.fetchStock('9999999999'),
          throwsA(isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 404)));
    });

    test('categories, schemas, facets and materials parse', () async {
      final categories = await source.fetchCategories();
      expect(categories, hasLength(10));
      final first = MaterialApiMapper.categoryFrom(categories.first);
      expect(first.materialCount, 6);

      final schemas = await source.fetchSchemas(categoryCode: first.code);
      expect(schemas.single.categoryId, first.code);

      final families = await source.fetchFacetOptions(
          attribute: 'Family', selection: {'categoryCode': first.code});
      expect(families.map(MaterialApiMapper.facetFrom), hasLength(3));

      final page = await source.fetchMaterials(
        selection: {'categoryCode': first.code, 'family': 'TRIM-7'},
        page: 1,
        pageSize: 20,
      );
      expect(page.totalRecords, 2);
      final material = MaterialApiMapper.materialFrom(page.rows.first);
      expect(material.materialCode, '1400000691');
    });

    test('an unbounded material read is refused', () {
      expect(
          source.fetchMaterials(selection: const {}, page: 1, pageSize: 20),
          throwsA(isA<ApiException>()
              .having((e) => e.code, 'code', 'Material.SelectionNotBounded')));
    });

    test('offline → network error', () {
      network.setOnline(false);
      expect(source.fetchStock('2400001018'), _offline);
      expect(source.fetchCategories(), _offline);
    });
  });
}
