import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/my_visits/domain/entities/stock_level.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_stock_update.dart';
import 'package:steelforce/features/my_visits/presentation/widgets/stock_level_selector.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/shared/widgets/app_bottom_sheet.dart';
import 'package:steelforce/shared/widgets/keyboard_aware_scroll_view.dart';

/// Bottom sheet for a one-off stock status capture from the stop detail
/// screen: product name + a single Low / Medium / High selection (no numeric
/// quantity). Save is disabled until both are provided.
Future<VisitStockUpdate?> showStockUpdateSheet(
    {required BuildContext context, required String stopId}) {
  final productController = TextEditingController();
  final notesController = TextEditingController();
  StockLevel? level;

  return showModalBottomSheet<VisitStockUpdate>(
    constraints: const BoxConstraints(maxWidth: AppBottomSheet.maxWidth),
    context: context,
    backgroundColor: context.appColors.surfaceSoft,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (context) => StatefulBuilder(
      // Was a hand-rolled `Padding(viewInsets) + SafeArea`. AppBottomSheet owns
      // the keyboard inset, the safe area and the 0.9 height cap this sheet
      // never had — without the cap, these fields plus the keyboard overflow
      // on a short screen.
      builder: (context, setSheetState) => AppBottomSheet(
        showHandle: false,
        child: KeyboardAwareScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('my_visits.forms.update_stock'.tr,
                  style: TextStyle(
                      color: context.appColors.textPrimary,
                      fontSize: context.rsp(17),
                      fontWeight: FontWeight.w800)),
              SizedBox(height: context.rh(12)),
              TextField(
                  controller: productController,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setSheetState(() {}),
                  decoration: InputDecoration(
                      hintText: 'my_visits.forms.product_name'.tr)),
              SizedBox(height: context.rh(14)),
              Text('my_visits.forms.stock_status'.tr,
                  style: TextStyle(
                      color: context.appColors.textSecondary,
                      fontSize: context.rsp(12.5),
                      fontWeight: FontWeight.w700)),
              SizedBox(height: context.rh(8)),
              SizedBox(
                width: double.infinity,
                child: StockLevelSelector(
                  value: level,
                  onChanged: (selected) =>
                      setSheetState(() => level = selected),
                ),
              ),
              SizedBox(height: context.rh(10)),
              TextField(
                  controller: notesController,
                  textInputAction: TextInputAction.done,
                  decoration:
                      InputDecoration(hintText: 'common.notes_optional'.tr)),
              SizedBox(height: context.rh(16)),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      productController.text.trim().isEmpty || level == null
                          ? null
                          : () {
                              Navigator.pop(
                                context,
                                VisitStockUpdate(
                                  id: '${DateTime.now().microsecondsSinceEpoch}',
                                  stopId: stopId,
                                  productId: productController.text.trim(),
                                  productName: productController.text.trim(),
                                  stockLevel: level!,
                                  notes: notesController.text.trim(),
                                ),
                              );
                            },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
