import 'package:flutter/material.dart';
import 'package:steelforce/core/animations/app_animations.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/app_colors.dart';

/// The mode pill's icon and word, animated on every switch: the icon turns
/// and pops in, the word slides up, the icon's ring eases to the new colour.
/// [motion] is [Duration.zero] under Reduce Motion.
class WorkModePillContent extends StatelessWidget {
  const WorkModePillContent({
    super.key,
    required this.offline,
    required this.switching,
    required this.label,
    required this.accent,
    required this.labelColor,
    required this.motion,
  });

  final bool offline;
  final bool switching;
  final String label;
  final Color accent;
  final Color labelColor;
  final Duration motion;

  String get _iconKey => switching ? 'busy' : (offline ? 'off' : 'on');

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: motion,
          curve: AppCurves.standard,
          padding: EdgeInsets.all(context.rr(5)),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accent.withValues(alpha: 0.14),
            border: Border.all(
              color: AppColors.steelRim.withValues(alpha: 0.8),
            ),
          ),
          // The icon turns and pops in; the old one fades out.
          child: AnimatedSwitcher(
            duration: motion,
            switchInCurve: AppCurves.bounce,
            switchOutCurve: AppCurves.standard,
            transitionBuilder: (child, animation) => RotationTransition(
              turns: Tween(begin: -0.25, end: 0.0).animate(animation),
              child: ScaleTransition(
                scale: animation,
                child: FadeTransition(opacity: animation, child: child),
              ),
            ),
            child: switching
                ? SizedBox(
                    key: ValueKey(_iconKey),
                    width: context.rr(14),
                    height: context.rr(14),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: accent,
                    ),
                  )
                : Icon(
                    offline ? Icons.phone_android_rounded : Icons.wifi_rounded,
                    key: ValueKey(_iconKey),
                    size: context.rsp(14),
                    color: accent,
                  ),
          ),
        ),
        SizedBox(width: context.rw(8)),
        // The new word slides up into place as the old one
        // fades away.
        AnimatedSwitcher(
          duration: motion,
          switchInCurve: AppCurves.emphasized,
          switchOutCurve: AppCurves.standard,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, 0.4),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: Text(
            label,
            key: ValueKey(offline),
            style: TextStyle(
              color: labelColor,
              fontSize: context.rsp(12.5),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
