import 'package:flutter/material.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

/// Bottom sheet for picking one or more KPI filter values (month / year).
///
/// At least one value always stays selected: unchecking the last one is
/// ignored. [onConfirm] fires only when the user taps Done.
void showKpiMultiSelectSheet({
  required BuildContext context,
  required String title,
  required List<String> options,
  required List<String> selectedValues,
  required ValueChanged<List<String>> onConfirm,
}) {
  List<String> tempSelected = List.from(selectedValues);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(context.rr(20)),
      ),
    ),
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          final scheme = Theme.of(context).colorScheme;
          return Container(
            padding: EdgeInsets.all(context.rw(16)),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Select $title',
                      style: TextStyle(
                        fontSize: context.rsp(16),
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        onConfirm(tempSelected);
                        Navigator.pop(context);
                      },
                      child: Text(
                        'Done',
                        style: TextStyle(
                          fontSize: context.rsp(14),
                          fontWeight: FontWeight.w700,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: ListView.builder(
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final item = options[index];
                      final isChecked = tempSelected.contains(item);
                      return CheckboxListTile(
                        title: Text(
                          item,
                          style: TextStyle(
                            fontSize: context.rsp(14),
                            fontWeight:
                                isChecked ? FontWeight.w700 : FontWeight.w400,
                          ),
                        ),
                        value: isChecked,
                        activeColor: scheme.primary,
                        onChanged: (bool? checked) {
                          setModalState(() {
                            if (checked == true) {
                              tempSelected.add(item);
                            } else {
                              if (tempSelected.length > 1) {
                                tempSelected.remove(item);
                              }
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
