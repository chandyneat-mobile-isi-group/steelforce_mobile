import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:steelforce/core/assets/app_assets.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

/// The top of the guest panel: the white SteelForce app icon, the white
/// wordmark and what the app is — on the navy panel in both themes.
///
/// The wordmark is the logo pack's `steelforce-wordmark-dark.svg`; the
/// endorsed lockup is not used here because the footer already carries the
/// ISI Steel mark.
class GuestLandingBrand extends StatelessWidget {
  const GuestLandingBrand({super.key});

  /// Width ÷ height of the wordmark artwork.
  static const _wordmarkRatio = 1408 / 215;

  @override
  Widget build(BuildContext context) {
    final tile = context.rr(52);
    final wordmark = context.rr(24);

    return Semantics(
      header: true,
      label: 'app.name'.tr,
      child: Row(
        children: [
          Image.asset(
            AppLogos.steelForceAppIconWhite,
            width: tile,
            height: tile,
            excludeFromSemantics: true,
            filterQuality: FilterQuality.medium,
          ),
          SizedBox(width: context.rw(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SvgPicture.asset(
                  AppLogos.steelForceWordmarkWhite,
                  height: wordmark,
                  width: wordmark * _wordmarkRatio,
                  excludeFromSemantics: true,
                ),
                SizedBox(height: context.rh(6)),
                Text(
                  'shell.guest.app_line'.tr,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: context.rsp(15),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
