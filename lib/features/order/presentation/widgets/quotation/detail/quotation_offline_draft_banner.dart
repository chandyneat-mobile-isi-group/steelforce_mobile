import 'package:flutter/material.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

/// Marks a quotation shown from the device copy because the server could not
/// be reached — the rep must not mistake it for the server's version.
class QuotationOfflineDraftBanner extends StatelessWidget {
  const QuotationOfflineDraftBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, color: Colors.amber.shade800, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Local Offline Draft: Saved on device (not yet on server).',
              style: TextStyle(
                color: Colors.amber.shade900,
                fontSize: context.rsp(12),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
