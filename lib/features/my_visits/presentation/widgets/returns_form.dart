import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_return.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/shared/widgets/app_bottom_sheet.dart';
import 'package:steelforce/shared/widgets/keyboard_aware_scroll_view.dart';

Future<VisitReturn?> showReturnsSheet(
    {required BuildContext context, required String stopId}) {
  final productController = TextEditingController();
  final qtyController = TextEditingController();
  final reasonController = TextEditingController();

  return showModalBottomSheet<VisitReturn>(
    constraints: const BoxConstraints(maxWidth: AppBottomSheet.maxWidth),
    context: context,
    backgroundColor: context.appColors.surfaceSoft,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    // Was a hand-rolled `Padding(viewInsets) + SafeArea` — one of six copies
    // that escaped the sweep AppBottomSheet was written for. AppBottomSheet
    // owns the keyboard inset, the safe area *and* the 0.9 height cap this
    // sheet never had; without that cap a three-field form plus the keyboard
    // overflows on a short screen.
    builder: (context) => AppBottomSheet(
      // These sheets never showed a drag handle; this change is about
      // behaviour, not restyling.
      showHandle: false,
      child: KeyboardAwareScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('my_visits.forms.capture_return'.tr,
                style: TextStyle(
                    color: context.appColors.textPrimary,
                    fontSize: context.rsp(17),
                    fontWeight: FontWeight.w800)),
            SizedBox(height: context.rh(12)),
            TextField(
                controller: productController,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                    hintText: 'my_visits.forms.product_name'.tr)),
            SizedBox(height: context.rh(10)),
            TextField(
              controller: qtyController,
              textInputAction: TextInputAction.next,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                  hintText: 'my_visits.forms.quantity_returned'.tr),
            ),
            SizedBox(height: context.rh(10)),
            TextField(
                controller: reasonController,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(hintText: 'Reason')),
            SizedBox(height: context.rh(16)),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final qty = double.tryParse(qtyController.text);
                  if (productController.text.trim().isEmpty || qty == null) {
                    return;
                  }
                  Navigator.pop(
                    context,
                    VisitReturn(
                      id: '${DateTime.now().microsecondsSinceEpoch}',
                      stopId: stopId,
                      productId: productController.text.trim(),
                      productName: productController.text.trim(),
                      quantity: qty,
                      reason: reasonController.text.trim().isEmpty
                          ? 'common.not_specified'.tr
                          : reasonController.text.trim(),
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
  );
}
