import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

/// UI-only error state for the visit history list — no real fetch/retry logic
/// behind it, the caller wires [onRetry] to whatever it wants to re-run.
class VisitHistoryErrorState extends StatelessWidget {
  const VisitHistoryErrorState({super.key, required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: context.rh(72),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: scheme.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20)),
              child: Icon(Icons.cloud_off_rounded,
                  size: context.rr(34), color: scheme.error),
            ),
            SizedBox(height: context.rh(16)),
            Text(
              'my_visits.history.error_title'.tr,
              style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: context.rsp(15),
                  fontWeight: FontWeight.w800),
            ),
            SizedBox(height: context.rh(6)),
            Text(
              'my_visits.history.error_message'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: colors.textSecondary, fontSize: context.rsp(13)),
            ),
            SizedBox(height: context.rh(20)),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('my_visits.history.retry'.tr,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}
