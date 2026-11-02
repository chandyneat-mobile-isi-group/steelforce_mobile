import 'package:flutter/material.dart';
import 'package:steelforce/core/animations/staggered_list.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/app_coach/domain/entities/coach_module.dart';
import 'package:steelforce/features/app_coach/domain/entities/coach_status.dart';
import 'package:steelforce/features/app_coach/presentation/blocs/app_coach_bloc.dart';
import 'package:steelforce/shared/widgets/brand_wallpaper_background.dart';
import 'package:steelforce/core/assets/app_assets.dart';

/// Responsive lesson library opened from the coach assistant.
class CoachLessonsSheet extends StatelessWidget {
  const CoachLessonsSheet({
    super.key,
    required this.modules,
    required this.state,
    required this.onStart,
    required this.onResume,
    this.onWatch,
  });

  final List<CoachModule> modules;
  final AppCoachState state;
  final ValueChanged<String> onStart;
  final VoidCallback onResume;
  final ValueChanged<String>? onWatch;

  static Future<void> show(
    BuildContext context, {
    required List<CoachModule> modules,
    required AppCoachState state,
    required ValueChanged<String> onStart,
    required VoidCallback onResume,
    ValueChanged<String>? onWatch,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: scheme.surface,
      barrierColor: Colors.black.withValues(alpha: 0.48),
      elevation: 0,
      constraints: const BoxConstraints(maxWidth: 900),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      clipBehavior: Clip.antiAlias,
      builder: (sheet) => CoachLessonsSheet(
        modules: modules,
        state: state,
        onStart: (id) {
          Navigator.of(sheet).pop();
          onStart(id);
        },
        onResume: () {
          Navigator.of(sheet).pop();
          onResume();
        },
        onWatch: onWatch == null
            ? null
            : (id) {
                Navigator.of(sheet).pop();
                onWatch(id);
              },
      ),
    );
  }

  static IconData iconFor(String moduleId) => switch (moduleId) {
        CoachModuleIds.tour => Icons.explore_outlined,
        CoachModuleIds.depots => Icons.storefront_outlined,
        CoachModuleIds.quotation => Icons.request_quote_outlined,
        CoachModuleIds.order => Icons.shopping_cart_checkout_rounded,
        CoachModuleIds.visit => Icons.where_to_vote_outlined,
        _ => Icons.school_outlined,
      };

  static String coverFor(String moduleId) => switch (moduleId) {
        CoachModuleIds.tour => AppImages.guestFactoryHero,
        CoachModuleIds.depots => AppImages.lessonDepotsCover,
        CoachModuleIds.quotation => AppImages.lessonQuotationCover,
        CoachModuleIds.visit => AppImages.lessonVisitCover,
        _ => AppImages.guestFactoryHero,
      };

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final media = MediaQuery.of(context);
    final reduceMotion = media.disableAnimations;

    final lessonCards = [
      for (final module in modules.where((m) => m.id != CoachModuleIds.order))
        _LessonTile(
          module: module,
          status: _statusOf(module),
          compact: true,
          onStart: () => onStart(module.id),
          onResume: onResume,
          onWatch: module.practice && onWatch != null
              ? () => onWatch!(module.id)
              : null,
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final wide = width >= 720;
        final contentWidth = wide ? 820.0 : double.infinity;
        final cardAspectRatio = width >= 720
            ? 0.82
            : width >= 480
                ? 0.68
                : 0.56;
        final animatedCards = StaggeredList.wrap(
          lessonCards,
          interval: const Duration(milliseconds: 55),
          baseDelay: const Duration(milliseconds: 70),
          duration: const Duration(milliseconds: 380),
          offset: 18,
          enabled: !reduceMotion,
        );

        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: media.size.height * 0.9,
            maxWidth: 900,
          ),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SheetHeader(
                  title: 'coach.lessons.title'.tr,
                  subtitle: 'coach.lessons.subtitle'.tr,
                  onClose: () => Navigator.of(context).pop(),
                ),
                Divider(height: 1, color: colors.border.withValues(alpha: 0.7)),
                Flexible(
                  child: BrandWallpaperBody(
                      child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    padding: EdgeInsets.fromLTRB(
                      context.pagePadding,
                      context.rh(16),
                      context.pagePadding,
                      context.rh(24) + media.padding.bottom,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: contentWidth),
                        child: GridView.count(
                          crossAxisCount: 2,
                          crossAxisSpacing: context.rw(wide ? 14 : 10),
                          mainAxisSpacing: context.rh(wide ? 14 : 10),
                          childAspectRatio: cardAspectRatio,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: animatedCards,
                        ),
                      ),
                    ),
                  )),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  _LessonStatus _statusOf(CoachModule module) {
    final current = state.module?.id == module.id;
    if (current && state.status == CoachStatus.paused) {
      return _LessonStatus.paused;
    }
    if (current && state.status == CoachStatus.running) {
      return _LessonStatus.running;
    }
    if (state.interruptedModuleId == module.id) {
      return _LessonStatus.interrupted;
    }
    if (state.completedModuleIds.contains(module.id)) {
      return _LessonStatus.done;
    }
    return _LessonStatus.fresh;
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.title,
    required this.subtitle,
    required this.onClose,
  });

  final String title;
  final String subtitle;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.pagePadding,
        context.rh(8),
        context.rw(8),
        context.rh(16),
      ),
      child: Row(
        children: [
          Container(
            width: context.rr(50),
            height: context.rr(50),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  scheme.primary.withValues(alpha: 0.16),
                  scheme.primary.withValues(alpha: 0.07),
                ],
              ),
              borderRadius: BorderRadius.circular(context.rr(16)),
              border: Border.all(color: scheme.primary.withValues(alpha: 0.12)),
            ),
            child: Icon(Icons.auto_awesome_rounded,
                color: scheme.primary, size: context.rr(25)),
          ),
          SizedBox(width: context.rw(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: context.rsp(20),
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.35,
                    color: colors.textPrimary,
                  ),
                ),
                SizedBox(height: context.rh(3)),
                Text(
                  subtitle,
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
          SizedBox(width: context.rw(8)),
          IconButton.filledTonal(
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

enum _LessonStatus { fresh, running, paused, interrupted, done }

class _LessonTile extends StatelessWidget {
  const _LessonTile({
    required this.module,
    required this.status,
    required this.compact,
    required this.onStart,
    required this.onResume,
    this.onWatch,
  });

  final CoachModule module;
  final _LessonStatus status;
  final bool compact;
  final VoidCallback onStart;
  final VoidCallback onResume;
  final VoidCallback? onWatch;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final (String statusLabel, Color statusColor) = switch (status) {
      _LessonStatus.done => ('coach.lessons.status.done'.tr, colors.success),
      _LessonStatus.running || _LessonStatus.paused => (
          'coach.lessons.status.in_progress'.tr,
          scheme.primary,
        ),
      _LessonStatus.interrupted => (
          'coach.lessons.status.interrupted'.tr,
          colors.warning,
        ),
      _LessonStatus.fresh => ('coach.lessons.status.new'.tr, colors.textHint),
    };
    final (String action, VoidCallback onTap) = switch (status) {
      _LessonStatus.paused => ('coach.lessons.continue'.tr, onResume),
      _LessonStatus.running => ('coach.lessons.restart'.tr, onStart),
      _LessonStatus.done => ('coach.lessons.again'.tr, onStart),
      _LessonStatus.interrupted => ('coach.lessons.start_again'.tr, onStart),
      _LessonStatus.fresh => ('coach.lessons.start'.tr, onStart),
    };
    final accent = scheme.primary;

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(context.rr(20)),
        border: Border.all(color: colors.border.withValues(alpha: 0.85)),
        boxShadow: [
          BoxShadow(
            color: colors.shadowColor.withValues(alpha: 0.07),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final coverHeight = (constraints.maxWidth * 0.52)
                  .clamp(context.rh(78), context.rh(158));
              return SizedBox(
                height: coverHeight,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  clipBehavior: Clip.none,
                  children: [
                    Image.asset(
                      CoachLessonsSheet.coverFor(module.id),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => ColoredBox(
                        color: accent.withValues(alpha: 0.12),
                        child: Icon(
                          CoachLessonsSheet.iconFor(module.id),
                          color: accent,
                          size: context.rr(38),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.12),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: context.rh(9),
                      right: context.rw(9),
                      child: _StatusPill(
                        label: statusLabel,
                        color: statusColor,
                        compact: true,
                        showCheck: status == _LessonStatus.done,
                      ),
                    ),
                    Positioned(
                      left: context.rw(12),
                      bottom: -context.rh(17),
                      child: Container(
                        width: context.rr(42),
                        height: context.rr(42),
                        decoration: BoxDecoration(
                          color: colors.card,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: colors.shadowColor.withValues(alpha: 0.12),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(
                          CoachLessonsSheet.iconFor(module.id),
                          color: accent,
                          size: context.rr(21),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                context.rw(13),
                context.rh(23),
                context.rw(13),
                context.rh(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    module.titleKey.tr,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: context.rsp(compact ? 13 : 15),
                      fontWeight: FontWeight.w800,
                      height: 1.18,
                      color: colors.textPrimary,
                    ),
                  ),
                  SizedBox(height: context.rh(5)),
                  Expanded(
                    child: Text(
                      module.summaryKey.tr,
                      maxLines: compact ? 4 : 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: context.rsp(compact ? 11 : 12.5),
                        height: 1.35,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                  SizedBox(height: context.rh(3)),
                  Row(
                    children: [
                      if (onWatch case final watch?
                          when status != _LessonStatus.paused)
                        Expanded(
                          child: TextButton.icon(
                            onPressed: watch,
                            icon: Icon(Icons.play_circle_outline_rounded,
                                size: context.rr(18)),
                            label: Text(
                              'coach.autoplay.watch'.tr,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: TextButton.styleFrom(
                              alignment: Alignment.centerLeft,
                              minimumSize: Size(0, context.rh(38)),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        )
                      else
                        const Spacer(),
                      IconButton.filledTonal(
                        tooltip: action,
                        onPressed: onTap,
                        style: IconButton.styleFrom(
                          minimumSize: Size.square(context.rr(40)),
                          maximumSize: Size.square(context.rr(40)),
                          padding: EdgeInsets.zero,
                        ),
                        icon: Icon(
                          status == _LessonStatus.paused
                              ? Icons.play_arrow_rounded
                              : Icons.arrow_forward_rounded,
                          size: context.rr(19),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.color,
    this.compact = false,
    this.showCheck = false,
  });

  final String label;
  final Color color;
  final bool compact;
  final bool showCheck;

  @override
  Widget build(BuildContext context) => Container(
        constraints: BoxConstraints(maxWidth: context.rw(compact ? 116 : 150)),
        padding: EdgeInsets.symmetric(
          horizontal: context.rw(compact ? 6 : 9),
          vertical: context.rh(compact ? 4 : 5),
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showCheck) ...[
              Icon(Icons.check_circle_rounded,
                  size: context.rr(compact ? 12 : 14), color: color),
              SizedBox(width: context.rw(4)),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: context.rsp(compact ? 9 : 11),
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      );
}
