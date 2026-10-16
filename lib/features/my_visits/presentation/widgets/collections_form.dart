import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_collection.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/shared/widgets/app_bottom_sheet.dart';
import 'package:steelforce/shared/widgets/keyboard_aware_scroll_view.dart';

Future<VisitCollection?> showCollectionsSheet(
    {required BuildContext context, required String stopId}) {
  final amountController = TextEditingController();
  final referenceController = TextEditingController();
  final notesController = TextEditingController();
  var method = CollectionMethod.cash;

  return showModalBottomSheet<VisitCollection>(
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
      builder: (context, setState) => AppBottomSheet(
        showHandle: false,
        child: KeyboardAwareScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('my_visits.forms.record_collection'.tr,
                  style: TextStyle(
                      color: context.appColors.textPrimary,
                      fontSize: context.rsp(17),
                      fontWeight: FontWeight.w800)),
              SizedBox(height: context.rh(12)),
              TextField(
                controller: amountController,
                textInputAction: TextInputAction.next,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    hintText: 'Amount', prefixText: '\$ '),
              ),
              SizedBox(height: context.rh(10)),
              Wrap(
                spacing: 8,
                children: [
                  for (final m in CollectionMethod.values)
                    ChoiceChip(
                      label: Text(m.name),
                      selected: method == m,
                      onSelected: (_) => setState(() => method = m),
                    ),
                ],
              ),
              SizedBox(height: context.rh(10)),
              TextField(
                  controller: referenceController,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                      hintText: 'my_visits.forms.reference_optional'.tr)),
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
                  onPressed: () {
                    final amount = double.tryParse(amountController.text);
                    if (amount == null || amount <= 0) return;
                    Navigator.pop(
                      context,
                      VisitCollection(
                        id: '${DateTime.now().microsecondsSinceEpoch}',
                        stopId: stopId,
                        amount: amount,
                        method: method,
                        reference: referenceController.text.trim(),
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
