import 'package:flutter/material.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/depots/domain/entities/depot.dart';
import 'package:steelforce/features/depots/domain/entities/depot_filter.dart';
import 'package:steelforce/features/depots/domain/usecases/browse_depots.dart';
import 'package:steelforce/features/depots/domain/usecases/depot_params.dart';
import 'package:steelforce/features/order/domain/entities/credit_summary.dart';
import 'package:steelforce/features/order/domain/usecases/catalog_params.dart';
import 'package:steelforce/features/order/domain/usecases/get_credit_summary.dart';
import 'package:steelforce/features/order/presentation/screens/shop/shop_order_entry_screen.dart';
import 'package:steelforce/features/order/presentation/widgets/order_skeletons.dart';
import 'package:steelforce/features/order/presentation/widgets/shop/shop_tile.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

class ShopListScreen extends StatefulWidget {
  const ShopListScreen({
    super.key,
    required this.territory,
    this.skipOffVisitCheck = false,
    this.seedSearchTerm,
  });

  static const routeName = 'order-shop-list';

  final String territory;
  final bool skipOffVisitCheck;
  final String? seedSearchTerm;

  @override
  State<ShopListScreen> createState() => _ShopListScreenState();
}

class _ShopListScreenState extends State<ShopListScreen> {
  late Future<List<Depot>> _shopsFuture;

  @override
  void initState() {
    super.initState();
    _shopsFuture = _loadShops();
  }

  Future<List<Depot>> _loadShops() async {
    final result = await sl<BrowseDepots>()(
      BrowseDepotsParams(
          page: 0,
          pageSize: 500,
          filter: DepotFilter(territory: widget.territory)),
    );
    return result.when(
        success: (paged) => paged.items, failure: (_) => const []);
  }

  void _openOrderEntry(Depot depot) {
    Navigator.of(context).push(MaterialPageRoute(
      settings: const RouteSettings(name: ShopOrderEntryScreen.routeName),
      builder: (_) => ShopOrderEntryScreen(
        depot: depot,
        skipOffVisitCheck: widget.skipOffVisitCheck,
        seedSearchTerm: widget.seedSearchTerm,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(
        backgroundColor: colors.canvas,
        iconTheme: IconThemeData(color: colors.textPrimary),
        title: Text(widget.territory,
            style: TextStyle(
                color: colors.textPrimary,
                fontSize: context.rsp(17),
                fontWeight: FontWeight.w800)),
      ),
      body: FutureBuilder<List<Depot>>(
        future: _shopsFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              physics: const NeverScrollableScrollPhysics(),
              children: [
                OrderTileSkeleton(),
                OrderTileSkeleton(),
                OrderTileSkeleton()
              ],
            );
          }
          final shops = snapshot.data!;
          if (shops.isEmpty) {
            return Center(
                child: Text('orders.catalog.no_products'.tr,
                    style: TextStyle(color: colors.textSecondary)));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            children: [
              for (final shop in shops)
                _ShopTileWithCredit(
                    depot: shop, onTap: () => _openOrderEntry(shop))
            ],
          );
        },
      ),
    );
  }
}

class _ShopTileWithCredit extends StatefulWidget {
  const _ShopTileWithCredit({required this.depot, required this.onTap});
  final Depot depot;
  final VoidCallback onTap;

  @override
  State<_ShopTileWithCredit> createState() => _ShopTileWithCreditState();
}

class _ShopTileWithCreditState extends State<_ShopTileWithCredit> {
  late Future<CreditSummary?> _summaryFuture;

  @override
  void initState() {
    super.initState();
    _summaryFuture =
        sl<GetCreditSummary>()(GetCreditSummaryParams(widget.depot.id)).then(
      (result) => result.when(success: (s) => s, failure: (_) => null),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CreditSummary?>(
      future: _summaryFuture,
      builder: (context, snapshot) => ShopTile(
          depot: widget.depot,
          onTap: widget.onTap,
          creditSummary: snapshot.data),
    );
  }
}
