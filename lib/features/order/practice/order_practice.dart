import 'package:get_it/get_it.dart';
import 'package:steelforce/core/practice/practice_session.dart';
import 'package:steelforce/features/order/domain/repositories/cart_repository.dart';
import 'package:steelforce/features/order/domain/repositories/material_availability_repository.dart';
import 'package:steelforce/features/order/domain/repositories/pricing_repository.dart';
import 'package:steelforce/features/order/domain/repositories/product_filter_repository.dart';
import 'package:steelforce/features/order/domain/repositories/product_repository.dart';
import 'package:steelforce/features/order/domain/repositories/quotation_api_repository.dart';
import 'package:steelforce/features/order/domain/repositories/quotation_repository.dart';
import 'package:steelforce/features/order/domain/repositories/sales_order_repository.dart';
import 'package:steelforce/features/order/domain/repositories/sync_queue_repository.dart';
import 'package:steelforce/features/order/domain/services/sync_queue_processor.dart';
import 'package:steelforce/features/order/order_injection.dart';
import 'package:steelforce/features/order/practice/order_practice_data.dart';
import 'package:steelforce/features/order/practice/practice_cart_repository.dart';
import 'package:steelforce/features/order/practice/practice_pricing_repositories.dart';
import 'package:steelforce/features/order/practice/practice_product_repository.dart';
import 'package:steelforce/features/order/practice/practice_product_filter_repository.dart';
import 'package:steelforce/features/order/practice/practice_quotation_api_repository.dart';
import 'package:steelforce/features/order/practice/practice_quotation_repository.dart';
import 'package:steelforce/features/order/practice/practice_sales_order_repository.dart';
import 'package:steelforce/features/order/practice/practice_sync_queue_repository.dart';
import 'package:steelforce/features/order/presentation/services/quotation_sync_coordinator.dart';

/// The Orders feature's practice stand-ins, registered into the practice
/// scope by [PracticeSession.start].
///
/// ## What is replaced
///
/// Every repository a quotation or sales-order lesson writes through, or that
/// would reach the backend for the demo depot: the local quotation, cart and
/// sales-order stores, the quotation API, depot pricing, SAP availability and
/// the outbound sync queue. Each stand-in wraps the real implementation and
/// forwards to it once the session ends. The use cases are then re-registered
/// ([registerOrderUseCases]) so they are built over the stand-ins; blocs are
/// factories and pick them up with no change to any screen.
///
/// ## What is deliberately left real
///
/// * **Master catalog reads** (`CategoryRepository`, `PromotionRepository`,
///   and ordinary `ProductRepository` reads). The guided material picker is
///   the exception: it uses a five-item static lesson catalog so both visit
///   and remote lessons work without a material API. `ProductRepository` is
///   wrapped so browse-time writes stay in memory.
/// * **Catalog sync** (`SyncRepository`) — the builder's `syncIfNeeded` may
///   refresh the device catalog during a lesson. That writes real master data
///   from the catalog feed, never anything practice produced.
/// * **The sync engine** (`SyncQueueProcessor`, `QuotationSyncCoordinator`).
///   They must keep pushing the rep's real work during a lesson. They are
///   resolved *before* any stand-in is registered, so a first-time creation
///   inside this scope still binds them to the real queue and the real
///   quotation store — practice data is never reachable from them.
void contributeOrderPractice(GetIt sl, PracticeWorld world) {
  // Pin the background sync machinery to the real stores first. A lazy
  // singleton created after the stand-ins below would capture them.
  if (sl.isRegistered<SyncQueueProcessor>()) sl<SyncQueueProcessor>();
  if (sl.isRegistered<QuotationSyncCoordinator>()) {
    sl<QuotationSyncCoordinator>();
  }

  // The real implementations, resolved before their stand-ins shadow them.
  final quotations = sl<QuotationRepository>();
  final quotationApi = sl<QuotationApiRepository>();
  final cart = sl<CartRepository>();
  final salesOrders = sl<SalesOrderRepository>();
  final pricing = sl<PricingRepository>();
  final availability = sl<MaterialAvailabilityRepository>();
  final syncQueue = sl<SyncQueueRepository>();
  final products = sl<ProductRepository>();
  final productFilters = sl<ProductFilterRepository>();

  final data = OrderPracticeData();
  world.onClose(data.dispose);

  sl
    ..registerSingleton<QuotationRepository>(
        PracticeQuotationRepository(real: quotations, world: world, data: data))
    ..registerSingleton<QuotationApiRepository>(PracticeQuotationApiRepository(
        real: quotationApi, world: world, data: data))
    ..registerSingleton<CartRepository>(
        PracticeCartRepository(real: cart, world: world, data: data))
    ..registerSingleton<SalesOrderRepository>(PracticeSalesOrderRepository(
        real: salesOrders, world: world, data: data))
    ..registerSingleton<PricingRepository>(
        PracticePricingRepository(real: pricing, world: world, data: data))
    ..registerSingleton<MaterialAvailabilityRepository>(
        PracticeMaterialAvailabilityRepository(
            real: availability, world: world, data: data))
    ..registerSingleton<SyncQueueRepository>(
        PracticeSyncQueueRepository(real: syncQueue, world: world))
    ..registerSingleton<ProductRepository>(
        PracticeProductRepository(real: products, world: world));

  sl.registerSingleton<ProductFilterRepository>(PracticeProductFilterRepository(
    real: productFilters,
    world: world,
  ));

  registerOrderUseCases(sl);
}
