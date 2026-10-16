import 'package:flutter/material.dart';
import 'package:steelforce/core/animations/app_animations.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';

/// "This arrives in a later version": an icon, a title, a line of
/// explanation and one way out. Shared by every switched-off feature
/// (`FeatureFlags`) so they all say it the same way.
class ComingSoonView extends StatelessWidget {
  const ComingSoonView({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.actionIcon,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final IconData actionIcon;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(context.rw(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.6, end: 1),
              duration: reduceMotion ? Duration.zero : AppDurations.page,
              curve: AppCurves.bounce,
              builder: (_, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: Container(
                width: context.rr(96),
                height: context.rr(96),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: scheme.primary, size: context.rr(44)),
              ),
            ),
            SizedBox(height: context.rh(20)),
            Text(title,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: context.rsp(20),
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary)),
            SizedBox(height: context.rh(8)),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: context.rsp(13.5), color: colors.textSecondary)),
            SizedBox(height: context.rh(24)),
            OutlinedButton.icon(
              onPressed: onAction,
              style: OutlinedButton.styleFrom(
                minimumSize: Size(context.rw(200), context.rh(48)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(context.rr(12))),
              ),
              icon: Icon(actionIcon),
              label: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
