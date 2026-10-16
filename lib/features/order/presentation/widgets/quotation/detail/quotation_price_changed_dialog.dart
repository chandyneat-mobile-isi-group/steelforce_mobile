import 'package:flutter/material.dart';

/// Shown on a 409 `Quotation.PriceChanged` from submit: SAP prices moved
/// since the quotation was built, so the rep must reprice before submitting.
Future<void> showQuotationPriceChangedDialog(
  BuildContext context, {
  required String message,
  required VoidCallback onReprice,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogCtx) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800),
          const SizedBox(width: 8),
          const Text('Price Changed in SAP'),
        ],
      ),
      content: Text(
        '$message\n\nLive SAP prices have moved since this quotation was created. Please reprice to view the updated amounts before submitting.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogCtx).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(dialogCtx).pop();
            onReprice();
          },
          child: const Text('Reprice and Review'),
        ),
      ],
    ),
  );
}
