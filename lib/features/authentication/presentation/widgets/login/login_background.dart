import 'package:flutter/material.dart';
import 'package:steelforce/core/theme/app_colors.dart';
import 'package:steelforce/features/authentication/presentation/widgets/auth_ink.dart';
import 'package:steelforce/shared/widgets/brand_pattern_background.dart';

/// The brand chevron backdrop of the sign-in and password-reset screens, in
/// white with a faint navy chevron, washed with a whisper of brand blue at
/// the top and bottom.
///
/// The middle stays the plain pattern, where the headline and the card sit;
/// the edges tint so the white card reads as lifted off the screen.
///
/// No blur: a full-screen filter costs a pass per frame while the keyboard
/// animates.
class LoginBackground extends StatelessWidget {
  const LoginBackground({super.key, this.opacity});

  /// Drives the entrance fade. Null: fully shown.
  final Animation<double>? opacity;

  @override
  Widget build(BuildContext context) {
    const tint = AppColors.primary;
    final stack = Stack(
      fit: StackFit.expand,
      children: [
        const BrandPatternBackground(
          color: Colors.white,
          lineColor: AuthInk.patternLine,
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                tint.withValues(alpha: 0.06),
                tint.withValues(alpha: 0.0),
                tint.withValues(alpha: 0.0),
                tint.withValues(alpha: 0.08),
              ],
              stops: const [0.0, 0.32, 0.6, 1.0],
            ),
          ),
        ),
        const RepaintBoundary(child: CustomPaint(painter: _HorizonGlow())),
      ],
    );
    final fade = opacity;
    return fade == null ? stack : FadeTransition(opacity: fade, child: stack);
  }
}

/// A soft ambient haze near the bottom edge without any harsh circular line.
class _HorizonGlow extends CustomPainter {
  const _HorizonGlow();

  @override
  void paint(Canvas canvas, Size size) {
    final crown = size.height - 22;
    final haze = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.signalBlue.withValues(alpha: 0.10),
          AppColors.signalBlue.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCenter(
        center: Offset(size.width / 2, crown + size.height * 0.04),
        width: size.width * 1.4,
        height: size.height * 0.22,
      ));
    canvas.drawRect(Offset.zero & size, haze);
  }

  @override
  bool shouldRepaint(_HorizonGlow oldDelegate) => false;
}
