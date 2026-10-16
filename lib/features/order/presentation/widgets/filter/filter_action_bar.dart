import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

/// Floating bottom action bar for the filter experience: a secondary "Reset"
/// action and a primary "Apply" button that doubles as a live result counter
/// ("Showing 245 products"). Presentational — all behaviour is delegated to
/// the two callbacks so it can sit above any result list.
class FilterActionBar extends StatelessWidget {
  const FilterActionBar({
    super.key,
    required this.resultCount,
    required this.onReset,
    required this.onApply,
    this.canReset = true,
    this.loading = false,
  });

  /// Number of products matching the current filter. When [loading] is true
  /// the count is replaced by a spinner instead of a possibly-stale number.
  final int resultCount;
  final VoidCallback onReset;
  final VoidCallback onApply;
  final bool canReset;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: context.appColors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            OutlinedButton(
              onPressed: canReset ? onReset : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
                side: BorderSide(
                    color: theme.colorScheme.error.withValues(alpha: 0.4)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text('common.reset'.tr,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            SizedBox(width: context.rw(12)),
            Expanded(
              child: ElevatedButton(
                onPressed: loading ? null : onApply,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      theme.colorScheme.primary.withValues(alpha: 0.6),
                  disabledForegroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        _applyLabel,
                        style: TextStyle(
                            fontSize: context.rsp(14),
                            fontWeight: FontWeight.w800),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _applyLabel {
    if (resultCount <= 0) return 'orders.catalog.no_products'.tr;
    return 'orders.filter.show_products'.trParams({'count': resultCount});
  }
}
