import 'package:flutter/material.dart';
import 'package:steelforce/core/network/api/api_defaults.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/theme_extensions.dart'; // 👈 ADJUST THIS PATH TO YOUR THEME EXTENSION FILE
import 'package:steelforce/features/depots/domain/entities/depot.dart';
import 'package:steelforce/features/depots/domain/usecases/browse_depots.dart';
import 'package:steelforce/features/depots/domain/usecases/depot_params.dart';
import 'package:steelforce/features/depots/presentation/bloc/depot_sync_cubit.dart';
import 'package:steelforce/features/order/presentation/screens/shop/shop_list_screen.dart';
import 'package:steelforce/features/order/presentation/widgets/order_skeletons.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

class TerritoryScreen extends StatefulWidget {
  const TerritoryScreen({super.key});

  static const routeName = 'order-territory';

  @override
  State<TerritoryScreen> createState() => _TerritoryScreenState();
}

class _TerritoryScreenState extends State<TerritoryScreen> {
  late Future<Map<String, int>> _territoriesFuture;

  @override
  void initState() {
    super.initState();
    _territoriesFuture = _loadTerritories();
  }

  Future<Map<String, int>> _loadTerritories() async {
    // Online-first: counts come from the API's current directory when it
    // answers in time; otherwise, or offline, from the local copy.
    await sl<DepotSyncCubit>()
        .syncIfNeeded()
        .timeout(ApiDefaults.onlineFirstWait, onTimeout: () {});
    final result = await sl<BrowseDepots>()(
        const BrowseDepotsParams(page: 0, pageSize: 5000));
    return result.when(
      success: (paged) {
        final counts = <String, int>{};
        for (final Depot c in paged.items) {
          counts[c.territory] = (counts[c.territory] ?? 0) + 1;
        }
        return counts;
      },
      failure: (_) => const {},
    );
  }

  void _openShopList(String territory) {
    Navigator.of(context).push(MaterialPageRoute(
      settings: const RouteSettings(name: ShopListScreen.routeName),
      builder: (_) => ShopListScreen(territory: territory),
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
        title: Text('orders.territory.title'.tr,
            style: TextStyle(
                color: colors.textPrimary,
                fontSize: context.rsp(17),
                fontWeight: FontWeight.w800)),
      ),
      body: FutureBuilder<Map<String, int>>(
        future: _territoriesFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const _TerritorySkeleton();
          }
          final territories = snapshot.data!.entries.toList()
            ..sort((a, b) => a.key.compareTo(b.key));
          if (territories.isEmpty) {
            return Center(
                child: Text('orders.territory.pick_territory'.tr,
                    style: TextStyle(color: colors.textSecondary)));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            children: [
              for (final entry in territories)
                _TerritoryTile(
                    name: entry.key,
                    shopCount: entry.value,
                    onTap: () => _openShopList(entry.key)),
            ],
          );
        },
      ),
    );
  }
}

class _TerritoryTile extends StatelessWidget {
  const _TerritoryTile(
      {required this.name, required this.shopCount, required this.onTap});
  final String name;
  final int shopCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: colors
            .canvas, // 👈 CHANGED FROM colors.surface TO colors.canvas TO RESOLVE COMPILER ERROR
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: EdgeInsets.all(context.rr(14)),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.border)),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: context.rh(40),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: colors.surfaceSoft,
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.map_rounded, color: colors.accentPurple),
                ),
                SizedBox(width: context.rw(12)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: context.rsp(14),
                              fontWeight: FontWeight.w800)),
                      SizedBox(height: context.rh(2)),
                      Text(
                          'orders.territory.shop_count'
                              .tr
                              .replaceAll('{count}', '$shopCount'),
                          style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: context.rsp(12))),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: colors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TerritorySkeleton extends StatelessWidget {
  const _TerritorySkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        OrderTileSkeleton(),
        OrderTileSkeleton(),
        OrderTileSkeleton(),
        OrderTileSkeleton()
      ],
    );
  }
}
