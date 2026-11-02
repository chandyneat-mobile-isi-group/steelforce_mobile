import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';

/// Marks the whole screen as practice for as long as a practice lesson runs:
/// an amber edge around every screen, and a chip at the top saying so.
///
/// Demo depots and demo visits look exactly like real ones — that is the
/// point of practising on the real screens — so the rep must never be able to
/// mistake practice for work. The edge ignores touches; the chip sits in the
/// status-bar band, clear of every app bar's back button, and opens the
/// practice menu.
class PracticeFrame extends StatelessWidget {
  const PracticeFrame({
    super.key,
    required this.lessonTitle,
    required this.paused,
    required this.onTap,
  });

  final String lessonTitle;
  final bool paused;

  /// Null while it must not open anything (a sheet or dialog is up).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final amber = context.appColors.warning;
    final top = MediaQuery.paddingOf(context).top;
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: amber, width: 3),
              ),
            ),
          ),
        ),
        Positioned(
          top: top > 0 ? (top - context.rh(26)).clamp(0.0, top) : 0,
          left: 0,
          right: 0,
          child: Center(
            child: Semantics(
              button: true,
              label: '${'coach.practice.badge'.tr}. $lessonTitle. '
                  '${'coach.practice.menu_hint'.tr}',
              child: Material(
                color: amber,
                borderRadius: BorderRadius.circular(100),
                elevation: 2,
                child: InkWell(
                  borderRadius: BorderRadius.circular(100),
                  onTap: onTap,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: context.rh(26),
                      maxWidth: MediaQuery.sizeOf(context).width * 0.8,
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: context.rw(12), vertical: context.rh(4)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            paused
                                ? Icons.pause_circle_outline_rounded
                                : Icons.school_outlined,
                            size: context.rr(14),
                            color: Colors.black87,
                          ),
                          SizedBox(width: context.rw(6)),
                          Flexible(
                            child: Text(
                              paused
                                  ? 'coach.practice.badge_paused'.tr
                                  : 'coach.practice.badge'.tr,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: context.rsp(11.5),
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          SizedBox(width: context.rw(4)),
                          Icon(Icons.expand_more_rounded,
                              size: context.rr(14), color: Colors.black87),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A lesson's guide collapsed: one line with the step, tap to open it again.
/// Shown while a dialog or the keyboard is up, or when the rep minimised it.
class LessonChip extends StatelessWidget {
  const LessonChip({
    super.key,
    required this.title,
    required this.stepNumber,
    required this.totalSteps,
    required this.hasFailure,
    required this.onExpand,
  });

  final String title;
  final int stepNumber;
  final int totalSteps;
  final bool hasFailure;
  final VoidCallback? onExpand;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final accent = hasFailure ? scheme.error : scheme.primary;
    return Semantics(
      button: onExpand != null,
      label: '$title. ${'coach.lesson_step'.trParams({
            'n': '$stepNumber',
            'total': '$totalSteps'
          })}',
      child: Material(
        color: colors.card,
        elevation: 6,
        shadowColor: Colors.black26,
        borderRadius: BorderRadius.circular(100),
        child: InkWell(
          borderRadius: BorderRadius.circular(100),
          onTap: onExpand,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: context.rw(14)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    hasFailure
                        ? Icons.error_outline_rounded
                        : Icons.auto_awesome_rounded,
                    size: context.rr(18),
                    color: accent,
                  ),
                  SizedBox(width: context.rw(8)),
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: context.rsp(13),
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  SizedBox(width: context.rw(8)),
                  Text(
                    '$stepNumber/$totalSteps',
                    style: TextStyle(
                      fontSize: context.rsp(12),
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
                  ),
                  if (onExpand != null) ...[
                    SizedBox(width: context.rw(4)),
                    Icon(Icons.unfold_more_rounded,
                        size: context.rr(18), color: colors.iconMuted),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
