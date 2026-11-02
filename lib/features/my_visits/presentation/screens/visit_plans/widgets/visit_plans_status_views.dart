import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/my_visits/presentation/widgets/stop_card_skeleton.dart';

/// Loading: card-shaped shimmer, so the list arrives without a layout jump.
class VisitPlansSkeleton extends StatelessWidget {
  const VisitPlansSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'my_visits.plans.loading'.tr,
      // A Column, not a list: it sits inside the screen's own scroll view.
      child: const Column(
        children: [StopCardSkeleton(), StopCardSkeleton(), StopCardSkeleton()],
      ),
    );
  }
}

/// A centred icon, title and hint, with an optional action — the shared shape
/// of the empty and error views, so the two differ in words, not layout.
class VisitPlansMessage extends StatelessWidget {
  const VisitPlansMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.hint,
    this.actionLabel,
    this.onAction,
    this.isError = false,
  });

  final IconData icon;
  final String title;
  final String hint;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final accent = isError ? scheme.error : scheme.primary;
    // On a card for the same reason as the offline notice: text drawn
    // straight on the vivid wallpaper was hard to read.
    return Center(
      child: Container(
        margin: EdgeInsets.all(context.rw(20)),
        padding: EdgeInsets.symmetric(
            horizontal: context.rw(20), vertical: context.rh(24)),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(context.rr(20)),
          border: Border.all(color: colors.border),
          boxShadow: colors.cardShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(context.rr(14)),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: context.rw(30), color: accent),
            ),
            SizedBox(height: context.rh(12)),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: context.rsp(15),
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: context.rh(6)),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: colors.textSecondary, fontSize: context.rsp(13)),
            ),
            if (actionLabel != null && onAction != null) ...[
              SizedBox(height: context.rh(16)),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(actionLabel!),
                style: FilledButton.styleFrom(
                    minimumSize: Size(context.rw(140), 48)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Above a list read from the device: the plan as it was at [savedAt], not
/// the server's current one.
class VisitPlansSavedNotice extends StatelessWidget {
  const VisitPlansSavedNotice({super.key, required this.savedAt});

  final DateTime savedAt;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
        TimeOfDay.fromDateTime(savedAt),
        alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context));
    // On a solid card, not the wallpaper: grey text straight on the vivid
    // blue could not be read in daylight. The orange edge and icon keep it
    // reading as a warning; the words are in the body text colour.
    return Container(
      margin: EdgeInsets.only(bottom: context.rh(10)),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(context.rr(12)),
        border: Border.all(color: colors.warning.withValues(alpha: 0.45)),
        boxShadow: colors.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: context.rw(4), color: colors.warning),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: context.rw(12), vertical: context.rh(10)),
                child: Row(
                  children: [
                    Icon(Icons.cloud_off_rounded,
                        size: context.rr(18), color: colors.warning),
                    SizedBox(width: context.rw(10)),
                    Expanded(
                      child: Text(
                        'my_visits.plans.saved_copy'
                            .tr
                            .replaceAll('{time}', time),
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: context.rsp(12.5),
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
