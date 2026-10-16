// GENERATED — category_icon_tokens.dart
// One hue per catalogue family. Icons are duotone on a single colour:
// strokes at full value, accent shapes at 16% (30% active) inside the SVG.

import 'package:flutter/material.dart';

enum CategoryFamily {
  product,
  raw,
  semi,
  finished,
  fitting,
  part,
  supply,
  misc
}

class CategoryIconTokens {
  const CategoryIconTokens._();

  // Sizes
  static const double sizeGrid = 26; // inside a 48 chip — dashboard grid
  static const double sizeNav = 24; // bottom navigation
  static const double sizeCompact = 20; // list rows, chips, 32 px wells
  static const double chipGrid = 48;
  static const double chipCompact = 32;

  // Motion
  static const Duration appear = Duration(milliseconds: 300);
  static const Duration press = Duration(milliseconds: 140);
  static const Duration state = Duration(milliseconds: 220);
  static const Duration ambient = Duration(milliseconds: 3600);
  static const Curve easeOut = Curves.easeOutCubic;
  static const Curve easeSoft = Curves.easeInOutCubic;

  static const Map<CategoryFamily, Color> light = {
    CategoryFamily.product: Color(0xFF5B7089),
    CategoryFamily.raw: Color(0xFF4E7FB6),
    CategoryFamily.semi: Color(0xFF3E8B82),
    CategoryFamily.finished: Color(0xFF6470B4),
    CategoryFamily.fitting: Color(0xFF4E8A62),
    CategoryFamily.part: Color(0xFF96794A),
    CategoryFamily.supply: Color(0xFF7A6AA6),
    CategoryFamily.misc: Color(0xFF6B7482),
  };

  static const Map<CategoryFamily, Color> dark = {
    CategoryFamily.product: Color(0xFFA9BACD),
    CategoryFamily.raw: Color(0xFF8CB8E6),
    CategoryFamily.semi: Color(0xFF6FC3B9),
    CategoryFamily.finished: Color(0xFFA3ABEE),
    CategoryFamily.fitting: Color(0xFF86C89C),
    CategoryFamily.part: Color(0xFFD6B47A),
    CategoryFamily.supply: Color(0xFFB4A7DD),
    CategoryFamily.misc: Color(0xFFA7B0BE),
  };

  /// Glyph colour for a family in the current theme.
  static Color of(BuildContext context, CategoryFamily family) {
    final map = Theme.of(context).brightness == Brightness.dark ? dark : light;
    return map[family]!;
  }

  /// Well behind the glyph. Inactive is neutral; active picks up the hue.
  static Color chip(BuildContext context, CategoryFamily family,
      {bool active = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!active)
      return isDark ? const Color(0xFF1E2731) : const Color(0xFFF1F3F7);
    return of(context, family).withOpacity(isDark ? 0.16 : 0.12);
  }
}
