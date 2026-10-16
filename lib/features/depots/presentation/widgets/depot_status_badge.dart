import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/depots/domain/entities/depot_status.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

/// Localized display label for a [DepotStatus]. Kept here (presentation)
/// rather than on the domain enum so the entity stays free of any `.tr`/l10n
/// dependency. Reused by the filter sheet's status chips.
///
/// The API also returns a pre-translated `statusDisplay` for each depot.
/// This resolves the label locally instead, off the stable `status` code, so a
/// row rendered from the offline cache reads in the user's language even when
/// it was synced under a different one — and so a language switch is a plain
/// rebuild rather than a re-sync.
extension DepotStatusL10n on DepotStatus {
  String get localizedLabel => switch (this) {
        DepotStatus.draft => 'depots.status.draft'.tr,
        DepotStatus.pendingApproval => 'depots.status.pending_approval'.tr,
        DepotStatus.active => 'depots.status.active'.tr,
        DepotStatus.suspended => 'depots.status.suspended'.tr,
        DepotStatus.closed => 'depots.status.closed'.tr,
        DepotStatus.dormant => 'depots.status.dormant'.tr,
        DepotStatus.creditHold => 'depots.status.credit_hold'.tr,
      };
}

class DepotStatusBadge extends StatelessWidget {
  const DepotStatusBadge({
    super.key,
    required this.status,
    this.borderRadius,
    this.padding,
  });
  final DepotStatus status;

  /// Defaults to a pill. A card that pins the badge into its corner passes a
  /// shape matching its own corner.
  final BorderRadiusGeometry? borderRadius;
  final EdgeInsetsGeometry? padding;

  Color _color(ColorScheme scheme, AppThemeColors colors) => switch (status) {
        DepotStatus.active => colors.success,
        // Not yet cleared to trade — informational, not a fault.
        DepotStatus.draft ||
        DepotStatus.pendingApproval =>
          colors.textSecondary,
        // Blocked from trading, which a rep needs to notice before they start
        // writing an order.
        DepotStatus.suspended ||
        DepotStatus.closed ||
        DepotStatus.creditHold =>
          scheme.error,
        DepotStatus.dormant => colors.textSecondary,
      };

  @override
  Widget build(BuildContext context) {
    final color = _color(Theme.of(context).colorScheme, context.appColors);
    return Container(
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: borderRadius ?? BorderRadius.circular(20),
      ),
      // A Row wrapping a Flexible Text, not a bare Text: a Container sizes to
      // its child, so an inflexible label makes this badge un-shrinkable and it
      // overflows whatever Row it is dropped into once the text grows — at
      // 200% scale, or in Khmer, or on "Pending approval". The parent still has
      // to hand it bounded width (`Flexible`); this is the half that lets it
      // use it.
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              status.localizedLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: color,
                  fontSize: context.rsp(11),
                  fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
