import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';

/// One area of the app shown on the guest landing.
class GuestFeature {
  const GuestFeature(this.icon, this.label);
  final IconData icon;
  final String label;
}

/// The four areas a signed-in rep works in, side by side with thin dividers.
///
/// A guest can see what is behind the sign-in but not open it: every tile
/// calls [onRequireLogin].
class GuestFeatureStrip extends StatelessWidget {
  const GuestFeatureStrip({super.key, required this.onRequireLogin});

  final VoidCallback onRequireLogin;

  static List<GuestFeature> get features => [
        GuestFeature(Icons.location_on_rounded, 'shell.guest.visits'.tr),
        GuestFeature(Icons.groups_rounded, 'shell.guest.depots'.tr),
        GuestFeature(Icons.description_rounded, 'shell.guest.quotations'.tr),
        GuestFeature(Icons.inventory_2_rounded, 'shell.guest.orders'.tr),
      ];

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final items = features;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              Padding(
                padding: EdgeInsets.symmetric(vertical: context.rh(18)),
                child: VerticalDivider(
                    width: 1, thickness: 1, color: colors.border),
              ),
            Expanded(
              child: _FeatureTile(feature: items[i], onTap: onRequireLogin),
            ),
          ],
        ],
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({required this.feature, required this.onTap});

  final GuestFeature feature;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final box = context.rr(50);

    return Semantics(
      button: true,
      label: 'shell.login_required_label'.trParams({'feature': feature.label}),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: context.rh(6)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: box,
                height: box,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(feature.icon,
                    color: scheme.primary, size: context.rr(24)),
              ),
              SizedBox(height: context.rh(8)),
              Text(
                feature.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: context.rsp(13.5),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
