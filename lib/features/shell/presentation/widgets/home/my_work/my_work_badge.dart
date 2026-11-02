/// The small brand-blue pill in the corner of a My Work tile (e.g. "3 today").
/// Animates in/out when its text changes. Restyle the pill here.
library;

import 'package:flutter/material.dart';
import 'package:steelforce/core/animations/app_animations.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/app_colors.dart';

class MyWorkBadge extends StatelessWidget {
  const MyWorkBadge({super.key, required this.text});

  // Style constants (design units).
  static const double _padH = 8;
  static const double _padV = 3;
  static const double _radius = 100;
  static const double _fontSize = 9;

  final String text;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppDurations.medium,
      switchInCurve: AppCurves.emphasized,
      transitionBuilder: (child, animation) => ScaleTransition(
        scale: animation,
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: Container(
        key: ValueKey<String>(text),
        padding: EdgeInsets.symmetric(
          horizontal: context.rw(_padH),
          vertical: context.rh(_padV),
        ),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.brandNavyDark],
          ),
          borderRadius: BorderRadius.circular(context.rr(_radius)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              offset: const Offset(0, 2),
              blurRadius: 4,
            ),
          ],
        ),
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white,
            fontSize: context.rsp(_fontSize),
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
