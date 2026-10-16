import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/features/shell/presentation/bloc/home_cubit.dart';
import 'package:steelforce/features/shell/presentation/widgets/work_icons/work_icon.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:steelforce/core/animations/app_animations.dart';
import 'package:steelforce/core/animations/fade_slide_transition.dart';
import 'package:steelforce/core/animations/shimmer_loading.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/app_colors.dart';
import 'package:steelforce/features/app_coach/presentation/services/coach_keys.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/route_sync_cubit.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/today_call_plan_count_cubit.dart';
import 'package:steelforce/core/network/api/api_defaults.dart';

class MyWorkGridSection extends StatelessWidget {
  const MyWorkGridSection({super.key});

  @override
  Widget build(BuildContext context) {
    return CoachKeys.wrap(
      CoachKeys.myWork,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.pagePadding,
          vertical: context.rh(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _SectionHeader('shell.my_work'.tr, letterSpacing: 1.6),

            // ── Top: My Visits (Full Width) ──────────────────────────────
            SizedBox(
              height: context.rh(120),
              width: double.infinity,
              child: FadeSlideIn(
                delay: FadeSlideIn.staggerDelay(1),
                child: CoachKeys.wrap(
                  CoachKeys.myVisits,
                  child: _TodayCallPlanCountScope(
                    child: BlocBuilder<TodayCallPlanCountCubit, int?>(
                      builder: (context, count) => _MyWorkCard(
                        label: 'shell.my_visits'.tr,
                        icon: Icons.assignment_turned_in_outlined,
                        kind: WorkIconKind.visits,
                        // Brand Guide §07 colours, one per card.
                        accent: AppColors.primary, // Apex Blue
                        tileHeight: context.rr(56),
                        // Hidden until the first read, so it never flashes a
                        // wrong "0 today".
                        badgeText: count == null
                            ? null
                            : 'shell.badge_today'.trParams({'count': count}),
                        isActive: true,
                        onTap: () =>
                            sl<ShellTabController>().goTo(ShellTab.myVisits),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            SizedBox(height: context.rh(12)),

            // ── Bottom: Depots & Quotes/Orders ─────────────────────────
            SizedBox(
              height: context.rh(120),
              child: Row(
                children: [
                  // Left: Depots
                  Expanded(
                    child: FadeSlideIn(
                      delay: FadeSlideIn.staggerDelay(2),
                      child: CoachKeys.wrap(
                        CoachKeys.myDepots,
                        child: _MyWorkCard(
                          label: 'shell.my_depots'.tr,
                          icon: Icons.people_alt_outlined,
                          kind: WorkIconKind.depots,
                          accent: AppColors.success, // Sustainable Green
                          isActive: false,
                          onTap: () =>
                              sl<ShellTabController>().goTo(ShellTab.depots),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(width: context.rw(12)),

                  // Right: Quotes & Orders
                  Expanded(
                    child: FadeSlideIn(
                      delay: FadeSlideIn.staggerDelay(3),
                      child: CoachKeys.wrap(
                        CoachKeys.orders,
                        child: _MyWorkCard(
                          label: 'shell.my_quotes_orders'.tr,
                          icon: Icons.description_outlined,
                          kind: WorkIconKind.quotesOrders,
                          accent: AppColors.brandBlaze, // Worksite Blaze
                          isActive: false,
                          onTap: () =>
                              sl<ShellTabController>().goTo(ShellTab.orders),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Owns the badge's [TodayCallPlanCountCubit] and keeps it online-first.
///
/// Each time Home is shown (and once on first build) it pulls today's routes
/// from the API, then recounts — so while online the badge is the server's
/// number, not the last synced one. The wait is capped at
/// [ApiDefaults.onlineFirstWait]; offline the pull fails fast and the badge
/// counts the local copy.
class _TodayCallPlanCountScope extends StatefulWidget {
  const _TodayCallPlanCountScope({required this.child});

  final Widget child;

  @override
  State<_TodayCallPlanCountScope> createState() =>
      _TodayCallPlanCountScopeState();
}

class _TodayCallPlanCountScopeState extends State<_TodayCallPlanCountScope> {
  late final TodayCallPlanCountCubit _cubit;
  late final RouteSyncCubit _sync;
  final ShellTabController _tabs = sl<ShellTabController>();

  @override
  void initState() {
    super.initState();
    _cubit = sl<TodayCallPlanCountCubit>();
    _sync = sl<RouteSyncCubit>();
    _tabs.addListener(_onTabChanged);
    _pullThenCount();
  }

  void _onTabChanged() {
    if (_tabs.value == ShellTab.home) _pullThenCount();
  }

  Future<void> _pullThenCount() async {
    await _sync
        .syncIfNeeded()
        .timeout(ApiDefaults.onlineFirstWait, onTimeout: () {});
    if (mounted) await _cubit.refresh();
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChanged);
    _sync.close();
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      BlocProvider.value(value: _cubit, child: widget.child);
}

class _MyWorkCard extends StatefulWidget {
  const _MyWorkCard({
    required this.label,
    required this.icon,
    required this.accent,
    required this.onTap,
    this.badgeText,
    this.isActive = false,
    required this.kind,
    this.tileHeight,
  });

  final String label;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;
  final String? badgeText;
  final bool isActive;

  /// Which drawn, animated illustration this card shows.
  final WorkIconKind kind;

  /// Tile height override.
  final double? tileHeight;

  @override
  State<_MyWorkCard> createState() => _MyWorkCardState();
}

class _MyWorkCardState extends State<_MyWorkCard> {
  bool _isPressed = false;

  // Traditional Gold Accent Palette
  static const Color _goldLight = Color(0xFFF3E5AB);
  static const Color _goldPrimary = Color(0xFFD4AF37);
  static const Color _goldDark = Color(0xFF996515);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final depthOffset = _isPressed ? 2.0 : 6.0;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _isPressed ? 4.0 : 0.0, 0),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20.r),
            boxShadow: [
              BoxShadow(
                color: widget.accent.withValues(alpha: isDark ? 0.35 : 0.25),
                offset: Offset(0, depthOffset),
                blurRadius: _isPressed ? 2 : 6,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.08),
                offset: Offset(0, depthOffset + 2),
                blurRadius: _isPressed ? 4 : 12,
              ),
            ],
          ),
          child: Stack(
            children: [
              // 1. Traditional Outer Gold Frame & Card Base
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20.r),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _goldLight.withValues(alpha: 0.8),
                      _goldPrimary,
                      _goldDark,
                    ],
                  ),
                ),
                padding: EdgeInsets.all(2.r),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18.r),
                    color: scheme.surface,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        scheme.surface,
                        Color.lerp(
                          scheme.surface,
                          widget.accent,
                          0.05,
                        )!,
                      ],
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18.r),
                    child: Stack(
                      children: [
                        // Traditional Corner Ornaments
                        Positioned(
                          top: -12.r,
                          left: -12.r,
                          child:
                              _TraditionalCornerOrnament(color: widget.accent),
                        ),
                        Positioned(
                          bottom: -12.r,
                          right: -12.r,
                          child: Transform.rotate(
                            angle: 3.14159,
                            child: _TraditionalCornerOrnament(
                                color: widget.accent),
                          ),
                        ),

                        // Card Content
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              WorkIcon(
                                kind: widget.kind,
                                accent: widget.accent,
                                size: widget.tileHeight ?? context.rr(66),
                              ),
                              SizedBox(height: context.rh(10)),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8.w),
                                child: Text(
                                  widget.label,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: context.rsp(13.5),
                                    fontWeight: FontWeight.w800,
                                    color: scheme.onSurface,
                                    letterSpacing: -0.1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 3. Badge with 3D Elevation
              if (widget.badgeText != null)
                Positioned(
                  top: 8.h,
                  right: 8.w,
                  child: _WorkBadge(text: widget.badgeText!),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Traditional geometric motif corner decoration
class _TraditionalCornerOrnament extends StatelessWidget {
  const _TraditionalCornerOrnament({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36.r,
      height: 36.r,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: color.withValues(alpha: 0.12),
          width: 2,
        ),
      ),
    );
  }
}

class _WorkBadge extends StatelessWidget {
  const _WorkBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppDurations.medium,
      switchInCurve: AppCurves.emphasized,
      transitionBuilder: (child, animation) => ScaleTransition(
        scale: animation,
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: Container(
        key: ValueKey<String>(text),
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFD4AF37), Color(0xFFB8860B)],
          ),
          borderRadius: BorderRadius.circular(100.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              offset: const Offset(0, 2),
              blurRadius: 4,
            ),
          ],
        ),
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white,
            fontSize: context.rsp(9),
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text, {this.letterSpacing = 1.6});

  final String text;
  final double letterSpacing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.textTheme.bodySmall?.color?.withValues(alpha: 0.8) ??
        theme.colorScheme.onSurface.withValues(alpha: 0.8);

    final double headerBase = context.responsive(compact: 14.0, medium: 16.0);

    return Padding(
      padding: EdgeInsets.only(left: 4.w, bottom: context.rh(12)),
      child: Row(
        children: [
          Container(
            width: context.rw(4),
            height: context.rh(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2.r),
              gradient: const LinearGradient(
                colors: [Color(0xFFD4AF37), Color(0xFF996515)],
              ),
            ),
          ),
          SizedBox(width: context.rw(8)),
          Text(
            text,
            style: TextStyle(
              fontSize: context.rsp(headerBase),
              fontWeight: FontWeight.w900,
              letterSpacing: letterSpacing,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class MyWorkGridSkeleton extends StatelessWidget {
  const MyWorkGridSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.pagePadding,
        vertical: context.rh(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _SectionHeader('shell.my_work'.tr, letterSpacing: 1.6),

          // Skeleton Top: Full width
          Container(
            height: context.rh(120),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20.r),
            ),
            alignment: Alignment.center,
            child: Shimmer(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ShimmerBox(
                    width: 48.r,
                    height: 48.r,
                    borderRadius: BorderRadius.circular(24.r),
                  ),
                  SizedBox(height: context.rh(12)),
                  ShimmerBox(width: 72.w, height: 12.h),
                ],
              ),
            ),
          ),

          SizedBox(height: context.rh(12)),

          // Skeleton Bottom: 2 Columns
          Row(children: [
            _skeletonCell(context),
            SizedBox(width: context.rw(12)),
            _skeletonCell(context)
          ]),
        ],
      ),
    );
  }

  Widget _skeletonCell(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        height: context.rh(120),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(20.r),
        ),
        alignment: Alignment.center,
        child: Shimmer(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ShimmerBox(
                width: 48.r,
                height: 48.r,
                borderRadius: BorderRadius.circular(24.r),
              ),
              SizedBox(height: context.rh(12)),
              ShimmerBox(width: 72.w, height: 12.h),
            ],
          ),
        ),
      ),
    );
  }
}
