import 'package:flutter/material.dart';
import 'package:steelforce/core/assets/app_assets.dart';

/// The ISI chevron — the brand pattern — as a small mark before a heading:
/// the Home greeting and "MY WORK".
///
/// Light theme: the Apex Blue artwork (`assets/partterns/isisteel
/// icon-02.png`, bundled resized as `assets/images/brand_chevron_blue.png`).
/// Dark theme: the pale steel one (`isisteel icon-01.png`, as
/// `assets/images/brand_chevron.png`), since blue sinks into dark surfaces.
///
/// Sized by [height]; the width follows the artwork (3814 × 1065).
/// Decorative, so screen readers skip it.
class BrandChevronMark extends StatelessWidget {
  const BrandChevronMark({super.key, required this.height});

  final double height;

  static const double _aspectRatio = 3814 / 1065;
  static const String lightThemeAsset = AppImages.brandChevronBlue;
  static const String darkThemeAsset = AppImages.brandChevronSteel;

  @override
  Widget build(BuildContext context) => Image.asset(
        Theme.of(context).brightness == Brightness.dark
            ? darkThemeAsset
            : lightThemeAsset,
        height: height,
        width: height * _aspectRatio,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        excludeFromSemantics: true,
      );
}
