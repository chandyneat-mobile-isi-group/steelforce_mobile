import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:steelforce/core/assets/app_assets.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

/// The Home bar's brand: the white app-icon tile, with the white wordmark and
/// what the app is beside it — the same lockup as the guest panel, sized for
/// the bar and set straight on the hero photo.
class AppBarBrand extends StatelessWidget {
  const AppBarBrand({super.key});

  /// Width ÷ height of the wordmark artwork.
  static const _wordmarkRatio = 1408 / 215;

  /// Lifts the white ink off the brighter parts of the photo.
  static final _shadow = Colors.black.withValues(alpha: 0.25);

  @override
  Widget build(BuildContext context) {
    final tile = context.rr(44);
    final wordmark = context.rr(20);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(context.rr(10)),
            boxShadow: [
              BoxShadow(
                  color: _shadow, offset: const Offset(0, 2), blurRadius: 8),
            ],
          ),
          child: Image.asset(
            AppLogos.steelForceAppIconWhite,
            width: tile,
            height: tile,
            excludeFromSemantics: true,
            filterQuality: FilterQuality.medium,
          ),
        ),
        SizedBox(width: context.rw(10)),
        // Scales down rather than overflowing beside the bell and avatar on a
        // narrow phone, or with the longer Khmer line.
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SvgPicture.asset(
                  AppLogos.steelForceWordmarkWhite,
                  height: wordmark,
                  width: wordmark * _wordmarkRatio,
                  excludeFromSemantics: true,
                ),
                SizedBox(height: context.rh(3)),
                Text(
                  'shell.guest.app_line'.tr,
                  maxLines: 1,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: context.rsp(12),
                    fontWeight: FontWeight.w600,
                    shadows: [Shadow(color: _shadow, blurRadius: 4)],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
