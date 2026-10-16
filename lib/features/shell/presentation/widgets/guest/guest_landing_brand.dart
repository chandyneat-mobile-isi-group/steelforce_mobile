import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/app_colors.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/shared/widgets/brand_logo.dart';

/// The top of the guest landing: the ISI STEEL mark, the SteelForce wordmark
/// ("Steel" navy, "Force" gold), the product line and a short gold rule.
///
/// The wordmark is drawn as text rather than cut from the artwork, so it stays
/// sharp at every size and follows the theme in dark mode.
class GuestLandingBrand extends StatelessWidget {
  const GuestLandingBrand({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final steelInk =
        isDark ? Theme.of(context).colorScheme.onSurface : AppColors.brandNavy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BrandLogo(
          height: context.rh(44),
          ink: isDark ? BrandLogoInk.auto : BrandLogoInk.brand,
        ),
        SizedBox(height: context.rh(14)),
        Semantics(
          header: true,
          label: 'app.name'.tr,
          child: ExcludeSemantics(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: 'Steel', style: TextStyle(color: steelInk)),
                    const TextSpan(
                      text: 'Force',
                      style: TextStyle(color: AppColors.brandGold),
                    ),
                  ],
                ),
                style: TextStyle(
                  fontSize: context.rsp(40),
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.2,
                  height: 1.05,
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: context.rh(4)),
        Text(
          'shell.guest.subtitle'.tr,
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: context.rsp(17),
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: context.rh(10)),
        Container(
          width: context.rw(52),
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.brandGold,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}
