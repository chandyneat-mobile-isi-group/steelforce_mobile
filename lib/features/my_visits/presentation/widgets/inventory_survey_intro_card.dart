import 'package:flutter/material.dart';
import 'package:steelforce/core/animations/app_animations.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';

/// The inventory step's opening card: what to photograph and how many.
class InventorySurveyIntroCard extends StatelessWidget {
  const InventorySurveyIntroCard({
    super.key,
    required this.minPhotos,
    required this.maxPhotos,
  });

  final int minPhotos;
  final int maxPhotos;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(context.rr(18)),
        border: Border.all(color: colors.border),
        boxShadow: colors.cardShadow,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(colors.card, scheme.primary, 0.08)!,
            colors.card,
          ],
        ),
      ),
      child: Stack(
        children: [
          // A watermark rather than a photo: the app has no depot imagery,
          // and a stock photo of somewhere else would mislead.
          Positioned(
            right: -context.rw(14),
            top: -context.rh(6),
            child: ExcludeSemantics(
              child: Icon(Icons.warehouse_rounded,
                  size: context.rr(128),
                  color: scheme.primary.withValues(alpha: 0.06)),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(context.rw(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.6, end: 1),
                      duration:
                          reduceMotion ? Duration.zero : AppDurations.page,
                      curve: AppCurves.bounce,
                      builder: (_, scale, child) =>
                          Transform.scale(scale: scale, child: child),
                      child: Container(
                        width: context.rr(52),
                        height: context.rr(52),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: scheme.primary.withValues(alpha: 0.12),
                        ),
                        child: Icon(Icons.add_a_photo_rounded,
                            color: scheme.primary, size: context.rr(26)),
                      ),
                    ),
                    SizedBox(width: context.rw(14)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('my_visits.survey.hero_title'.tr,
                              style: TextStyle(
                                  fontSize: context.rsp(17),
                                  fontWeight: FontWeight.w800,
                                  color: colors.textPrimary)),
                          SizedBox(height: context.rh(4)),
                          Text(
                            'my_visits.survey.hero_body'
                                .trParams({'min': minPhotos, 'max': maxPhotos}),
                            style: TextStyle(
                                fontSize: context.rsp(13),
                                height: 1.4,
                                color: colors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: context.rh(14)),
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: context.rw(12), vertical: context.rh(10)),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(context.rr(12)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_rounded,
                          color: scheme.primary, size: context.rr(20)),
                      SizedBox(width: context.rw(10)),
                      Expanded(
                        child: Text('my_visits.survey.hero_tip'.tr,
                            style: TextStyle(
                                fontSize: context.rsp(12),
                                height: 1.4,
                                color: scheme.primary)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
