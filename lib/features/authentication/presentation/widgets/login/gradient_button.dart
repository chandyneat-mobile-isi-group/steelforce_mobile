import 'package:flutter/material.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/app_colors.dart';

class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.trailingIcon,
  });

  /// Drawn at the far end, with the label staying centred — e.g. an arrow
  /// that says "this takes you in".
  final IconData? trailingIcon;

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final disabled = loading || onPressed == null;
    final borderRadius = BorderRadius.circular(context.rr(AppColors.radius));

    return Opacity(
      opacity: disabled ? 0.7 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppColors.ctaGradient,
          borderRadius: borderRadius,
          boxShadow: [
            BoxShadow(
              color: Theme.of(context)
                  .colorScheme
                  .secondary
                  .withValues(alpha: 0.35),
              blurRadius: context.rr(24),
              offset: Offset(0, context.rh(10)),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: borderRadius,
            onTap: disabled ? null : onPressed,
            child: SizedBox(
              height: context.rh(56),
              child: Center(
                child: loading
                    ? SizedBox(
                        width: context.rr(22),
                        height: context.rr(22),
                        child: const CircularProgressIndicator(
                          strokeWidth: 2.4,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    // Full width, so the trailing icon sits at the button's
                    // end rather than at the end of the label.
                    : Stack(
                        fit: StackFit.expand,
                        alignment: Alignment.center,
                        children: [
                          Padding(
                            // Clear of the trailing icon on a narrow button.
                            padding: EdgeInsets.symmetric(
                                horizontal:
                                    context.rw(trailingIcon == null ? 12 : 52)),
                            child: Center(
                              child: Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: context.rsp(16),
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          ),
                          if (trailingIcon case final icon?)
                            PositionedDirectional(
                              end: context.rw(20),
                              child: Icon(icon,
                                  color: Colors.white, size: context.rr(24)),
                            ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
