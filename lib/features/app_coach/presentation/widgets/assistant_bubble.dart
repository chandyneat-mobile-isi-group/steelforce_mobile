import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/app_coach/domain/entities/coach_step.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

/// The assistant tooltip: a compact card with an avatar, a short title + message
/// (≤ 2 lines), a slim progress bar, and one primary CTA (plus an optional
/// "Skip tour"). Const-friendly and theme-aware for light/dark.
class AssistantBubble extends StatelessWidget {
  const AssistantBubble({
    super.key,
    required this.step,
    required this.stepNumber,
    required this.totalSteps,
    required this.progress,
    required this.onCta,
    required this.onSkip,
    required this.onClose,
  });

  final CoachStep step;
  final int stepNumber;
  final int totalSteps;
  final double progress;
  final VoidCallback onCta;
  final VoidCallback onSkip;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      container: true,
      liveRegion: true,
      label: '${step.titleKey.tr}. ${step.messageKey.tr}',
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: EdgeInsets.fromLTRB(
              context.rw(18), context.rh(16), context.rw(16), context.rh(16)),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(context.rr(22)),
            border: Border.all(color: scheme.primary.withValues(alpha: 0.10)),
            boxShadow: [
              // Tight contact shadow for definition against the scrim...
              BoxShadow(
                color: colors.shadowColor.withValues(alpha: 0.14),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
              // ...plus a soft ambient shadow for lift.
              BoxShadow(
                color: colors.shadowColor.withValues(alpha: 0.20),
                blurRadius: 32,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Avatar(color: scheme.primary),
                  SizedBox(width: context.rw(12)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          step.titleKey.tr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: context.rsp(15.5),
                            fontWeight: FontWeight.w800,
                            color: colors.textPrimary,
                            letterSpacing: -0.3,
                            height: 1.15,
                          ),
                        ),
                        SizedBox(height: context.rh(4)),
                        Text(
                          step.messageKey.tr,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: context.rsp(12.5),
                            height: 1.35,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Dismiss → pause (surfaces the floating assistant to resume).
                  _IconButton(
                    icon: Icons.close_rounded,
                    tooltip: 'coach.cta.dismiss'.tr,
                    color: colors.iconMuted,
                    onTap: onClose,
                  ),
                ],
              ),
              SizedBox(height: context.rh(14)),
              _ProgressBar(
                value: progress,
                stepNumber: stepNumber,
                total: totalSteps,
                trackColor: colors.surfaceStrong,
                fillColor: scheme.primary,
              ),
              SizedBox(height: context.rh(14)),
              Row(
                children: [
                  if (step.canSkip)
                    _TextButton(
                      label: 'coach.cta.skip_tour'.tr,
                      color: colors.textHint,
                      onTap: onSkip,
                    ),
                  const Spacer(),
                  _PrimaryButton(
                    label: step.ctaKey.tr,
                    background: scheme.primary,
                    foreground: scheme.onPrimary,
                    onTap: onCta,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: context.rr(38),
        height: context.rr(38),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.24),
              color.withValues(alpha: 0.10),
            ],
          ),
          borderRadius: BorderRadius.circular(context.rr(13)),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Icon(Icons.auto_awesome_rounded,
            size: context.rr(20), color: color),
      );
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.value,
    required this.stepNumber,
    required this.total,
    required this.trackColor,
    required this.fillColor,
  });

  final double value;
  final int stepNumber;
  final int total;
  final Color trackColor;
  final Color fillColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: Container(
              height: context.rh(6),
              color: trackColor,
              alignment: Alignment.centerLeft,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeOutCubic,
                builder: (_, v, __) => FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: v,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(100),
                      gradient: LinearGradient(
                        colors: [
                          fillColor.withValues(alpha: 0.70),
                          fillColor,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: context.rw(10)),
        _StepPill(stepNumber: stepNumber, total: total, color: fillColor),
      ],
    );
  }
}

/// Tinted pill badge for "n/total" — reads as a status chip rather than a
/// plain caption, and keeps the same accent as the progress fill.
class _StepPill extends StatelessWidget {
  const _StepPill({
    required this.stepNumber,
    required this.total,
    required this.color,
  });

  final int stepNumber;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(
            horizontal: context.rw(8), vertical: context.rh(3)),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          '$stepNumber/$total',
          style: TextStyle(
            fontSize: context.rsp(11),
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      );
}

class _PrimaryButton extends StatefulWidget {
  const _PrimaryButton({
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.96 : 1.0,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOut,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(context.rr(14)),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(context.rr(14)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                widget.background,
                Color.lerp(widget.background, Colors.black, 0.14) ??
                    widget.background,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: widget.background.withValues(alpha: 0.32),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(context.rr(14)),
            onTap: () {
              HapticFeedback.selectionClick();
              widget.onTap();
            },
            onHighlightChanged: (v) => setState(() => _pressed = v),
            child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: context.rw(20), vertical: context.rh(11)),
              child: Text(
                widget.label,
                style: TextStyle(
                  fontSize: context.rsp(13),
                  fontWeight: FontWeight.w800,
                  color: widget.foreground,
                  letterSpacing: -0.1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TextButton extends StatelessWidget {
  const _TextButton(
      {required this.label, required this.color, required this.onTap});
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(context.rr(10)),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: context.rw(8), vertical: context.rh(8)),
          child: Text(
            label,
            style: TextStyle(
              fontSize: context.rsp(12.5),
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      );
}

class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          onPressed: onTap,
          tooltip: tooltip,
          visualDensity: VisualDensity.compact,
          constraints:
              BoxConstraints.tight(Size(context.rr(32), context.rr(32))),
          padding: EdgeInsets.zero,
          icon: Icon(icon, size: context.rr(16), color: color),
        ),
      );
}
