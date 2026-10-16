import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/order/domain/entities/product.dart'
    as catalog;
import 'package:steelforce/features/order/domain/usecases/browse_products.dart';
import 'package:steelforce/features/order/domain/usecases/catalog_params.dart'
    as catalog_params;
import 'package:steelforce/features/my_visits/domain/entities/visit_order_line.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/shared/widgets/app_bottom_sheet.dart';

/// Searches the real product catalog (`order` feature's `ProductRepository`,
/// via `BrowseProducts`) rather than inventing a second product concept —
/// one source of truth for products across the app.
Future<VisitOrderLine?> showOrderCaptureSheet(
    {required BuildContext context, required String stopId}) {
  return showModalBottomSheet<VisitOrderLine>(
    constraints: const BoxConstraints(maxWidth: AppBottomSheet.maxWidth),
    context: context,
    backgroundColor: context.appColors.surfaceSoft,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (_) => _OrderCaptureSheet(stopId: stopId),
  );
}

class _OrderCaptureSheet extends StatefulWidget {
  const _OrderCaptureSheet({required this.stopId});
  final String stopId;

  @override
  State<_OrderCaptureSheet> createState() => _OrderCaptureSheetState();
}

class _OrderCaptureSheetState extends State<_OrderCaptureSheet> {
  final _searchController = TextEditingController();
  List<catalog.Product> _results = const [];
  catalog.Product? _selected;
  double _quantity = 1;
  bool _searching = false;

  Future<void> _search(String query) async {
    setState(() => _searching = true);
    final result = await sl<BrowseProducts>()(
      catalog_params.BrowseProductsParams(page: 0, pageSize: 20, query: query),
    );
    if (!mounted) return;
    result.when(
      success: (paged) => setState(() {
        _results = paged.items;
        _searching = false;
      }),
      failure: (_) => setState(() {
        _results = const [];
        _searching = false;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final primary = Theme.of(context).colorScheme.primary;
    // AppBottomSheet replaces the hand-rolled `Padding(viewInsets) + SafeArea`
    // and adds the 0.9 height cap this sheet lacked. The inner ListView keeps
    // its own scrolling; no second scroll view is added here.
    return AppBottomSheet(
      showHandle: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('my_visits.forms.capture_order'.tr,
                style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: context.rsp(17),
                    fontWeight: FontWeight.w800)),
            SizedBox(height: context.rh(12)),
            TextField(
              controller: _searchController,
              onChanged: _search,
              decoration: InputDecoration(
                hintText: 'my_visits.forms.search_products'.tr,
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: colors.card,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
            ),
            SizedBox(height: context.rh(10)),
            if (_searching)
              Padding(
                  padding: EdgeInsets.all(context.rr(12)),
                  child: CircularProgressIndicator(color: primary)),
            if (!_searching && _results.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _results.length,
                  itemBuilder: (context, i) {
                    final p = _results[i];
                    final selected = _selected?.id == p.id;
                    return ListTile(
                      selected: selected,
                      selectedTileColor:
                          colors.surfaceStrong.withValues(alpha: 0.4),
                      title: Text(p.name,
                          style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: context.rsp(13),
                              fontWeight: FontWeight.w700)),
                      subtitle: Text(
                          '${p.code} · \$${p.effectivePrice.toStringAsFixed(2)}',
                          style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: context.rsp(11.5))),
                      onTap: () => setState(() => _selected = p),
                    );
                  },
                ),
              ),
            if (_selected != null) ...[
              SizedBox(height: context.rh(12)),
              Row(
                children: [
                  Expanded(
                    child: Text('Quantity',
                        style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: context.rsp(12.5))),
                  ),
                  IconButton(
                    onPressed: () => setState(
                        () => _quantity = (_quantity - 1).clamp(1, 99999)),
                    icon: const Icon(Icons.remove_circle_outline_rounded),
                  ),
                  Text(_quantity.toStringAsFixed(0),
                      style: TextStyle(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w800)),
                  IconButton(
                    onPressed: () => setState(() => _quantity++),
                    icon: const Icon(Icons.add_circle_outline_rounded),
                  ),
                ],
              ),
            ],
            SizedBox(height: context.rh(12)),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selected == null
                    ? null
                    : () => Navigator.pop(
                          context,
                          VisitOrderLine(
                            id: '${DateTime.now().microsecondsSinceEpoch}',
                            stopId: widget.stopId,
                            productId: _selected!.id,
                            productName: _selected!.name,
                            quantity: _quantity,
                            unit: _selected!.unit,
                            unitPrice: _selected!.effectivePrice,
                          ),
                        ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text('my_visits.forms.add_to_order'.tr),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
