import 'package:flutter/material.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';

/// Flat, theme-aware background for the enterprise CRM theme. Kept as its own
/// widget (rather than inlining the token everywhere) so screens that used
/// to layer content over the old dark "aurora" glow keep working unchanged.
///
/// Resolves to the active theme's soft surface, so it stays pixel-identical in
/// light mode and follows the dark palette automatically.
class AuroraBackground extends StatelessWidget {
  const AuroraBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(color: context.appColors.surfaceSoft);
  }
}
