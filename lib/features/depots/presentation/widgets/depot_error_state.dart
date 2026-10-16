import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';

/// Recoverable error state for depot-directory requests.
class DepotErrorState extends StatelessWidget {
  const DepotErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(context.rr(32)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: context.rr(48),
              color: Theme.of(context).colorScheme.error,
            ),
            SizedBox(height: context.rh(12)),
            Text(
              'common.something_went_wrong'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: context.rsp(16),
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: context.rh(6)),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: context.rsp(13),
              ),
            ),
            SizedBox(height: context.rh(16)),
            FilledButton(
              onPressed: onRetry,
              child: Text('common.try_again'.tr),
            ),
          ],
        ),
      ),
    );
  }
}
