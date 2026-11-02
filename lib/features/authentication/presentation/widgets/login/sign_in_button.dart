import 'package:flutter/material.dart';
import 'package:steelforce/core/animations/app_animations.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/app_colors.dart';

/// The sign-in screen's one primary action: a wide, lit pill.
///
/// A left-to-right [AppColors.signalBlue] gradient with a white label and a
/// blue glow beneath, as in the approved login artwork. The same in both
/// themes: the screen behind it is the dark brand backdrop either way.
///
/// While [loading] it shows a spinner, ignores taps (a second tap cannot send
/// a second sign-in) and keeps its size, so nothing below it moves.
class SignInButton extends StatefulWidget {
  const SignInButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon = Icons.arrow_forward_rounded,
    this.leading,
    this.iconTrailing = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData icon;

  /// A badge at the start, behind a hairline — e.g. the Google mark on the
  /// security check. The label then centres in the remaining width.
  final Widget? leading;

  /// The arrow at the end instead of before the label, as on the reset
  /// screens' "Continue".
  final bool iconTrailing;

  @override
  State<SignInButton> createState() => _SignInButtonState();
}

class _SignInButtonState extends State<SignInButton> {
  bool _pressed = false;

  void _press(bool down) {
    if (_pressed != down) setState(() => _pressed = down);
  }

  @override
  Widget build(BuildContext context) {
    const ink = Colors.white;
    // Pressed: the same gradient, a step deeper.
    final fill = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: _pressed
          ? [
              Color.lerp(AppColors.signalBlue, AppColors.brandNavy, 0.18)!,
              Color.lerp(AppColors.signalBlueLight, AppColors.brandNavy, 0.18)!,
            ]
          : const [AppColors.signalBlue, AppColors.signalBlueLight],
    );

    final enabled = !widget.loading && widget.onPressed != null;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final radius = BorderRadius.circular(context.rr(28));

    return AnimatedScale(
      scale: _pressed && !reduceMotion ? AppScale.pressedAction + 0.02 : 1,
      duration: _pressed ? AppDurations.pressDown : AppDurations.pressUp,
      curve: _pressed ? AppCurves.pressDown : AppCurves.standard,
      child: AnimatedOpacity(
        // Disabled (e.g. waiting out a rate limit): dimmed, not hidden.
        opacity: widget.onPressed == null && !widget.loading ? 0.55 : 1,
        duration: AppDurations.fast,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          curve: AppCurves.standard,
          height: context.rh(56).clamp(52.0, 64.0),
          decoration: BoxDecoration(
            gradient: fill,
            borderRadius: radius,
            // A light rim so the pill's edge holds against the glass card.
            border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
            boxShadow: [
              BoxShadow(
                color: AppColors.signalBlue
                    .withValues(alpha: enabled && !_pressed ? 0.5 : 0.2),
                blurRadius: context.rr(18),
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: radius,
              onTap: enabled ? widget.onPressed : null,
              onTapDown: enabled ? (_) => _press(true) : null,
              onTapUp: (_) => _press(false),
              onTapCancel: () => _press(false),
              splashColor: ink.withValues(alpha: 0.12),
              highlightColor: Colors.transparent,
              child: Center(
                child: AnimatedSwitcher(
                  duration: AppDurations.medium,
                  switchInCurve: AppCurves.standard,
                  switchOutCurve: AppCurves.standard,
                  transitionBuilder: (child, a) => FadeTransition(
                    opacity: a,
                    child: ScaleTransition(
                      scale: Tween(begin: 0.9, end: 1.0).animate(a),
                      child: child,
                    ),
                  ),
                  child: widget.loading
                      ? SizedBox(
                          key: const ValueKey('loading'),
                          width: context.rr(22),
                          height: context.rr(22),
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor: const AlwaysStoppedAnimation(ink),
                          ),
                        )
                      : KeyedSubtree(
                          key: const ValueKey('label'),
                          child: _content(context, ink),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, Color ink) {
    final label = Text(
      widget.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: ink,
        fontSize: context.rsp(17),
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
    );
    final arrow = Icon(widget.icon, color: ink, size: context.rr(22));

    if (widget.leading == null && !widget.iconTrailing) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: context.rw(16)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            arrow,
            SizedBox(width: context.rw(10)),
            Flexible(child: label),
          ],
        ),
      );
    }
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: context.rw(widget.leading == null ? 22 : 8),
        end: context.rw(22),
      ),
      child: Row(
        children: [
          if (widget.leading != null) ...[
            widget.leading!,
            Container(
              width: 1,
              height: context.rr(26),
              margin: EdgeInsets.symmetric(horizontal: context.rw(12)),
              color: ink.withValues(alpha: 0.3),
            ),
          ] else
            // Balances the arrow so the label sits in the true centre.
            SizedBox(width: context.rr(22)),
          Expanded(child: label),
          arrow,
        ],
      ),
    );
  }
}
