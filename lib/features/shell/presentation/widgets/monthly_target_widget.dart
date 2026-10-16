import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/localization/localized_text_context.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/shell/presentation/widgets/work_icons/calendar_month_icon.dart';

class MonthlyTargetCard extends StatefulWidget {
  const MonthlyTargetCard({
    super.key,
    required this.targetAmount,
    required this.achievedAmount,
    required this.monthName,
    this.onTap,
  });

  final double targetAmount;
  final String monthName;
  final double achievedAmount;
  final VoidCallback? onTap;

  @override
  State<MonthlyTargetCard> createState() => _MonthlyTargetCardState();
}

class _MonthlyTargetCardState extends State<MonthlyTargetCard>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  late final AnimationController _pulseController;
  late final Animation<double> _slideAnimation;

  // Traditional Gold Palette
  static const Color _goldLight = Color(0xFFF3E5AB);
  static const Color _goldPrimary = Color(0xFFD4AF37);
  static const Color _goldDark = Color(0xFF996515);

  double get _progress => widget.targetAmount > 0
      ? (widget.achievedAmount / widget.targetAmount).clamp(0.0, 1.0)
      : 0.0;

  int get _percentage => (_progress * 100).round();

  /// `100000` → `100,000$`: whole dollars, grouped in thousands, the sign
  /// after the amount. Truncated rather than rounded so the achieved figure
  /// never claims a dollar the rep has not reached yet.
  static String _dollars(BuildContext context, double amount) =>
      '${NumberFormat('#,##0', context.languageCode).format(amount.truncate())}\$';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _slideAnimation = Tween<double>(begin: 0.0, end: 4.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final appColors = context.appColors;
    final isDark = theme.brightness == Brightness.dark;
    // FS-ANI-7. The new calendar icon honours this itself; the arrow's drift
    // is driven from here, so it has to be read at this level too.
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    final depthOffset = _isPressed ? 2.0 : 6.0;

    return GestureDetector(
      onTapDown: (_) {
        if (widget.onTap != null) setState(() => _isPressed = true);
      },
      onTapUp: (_) {
        if (widget.onTap != null) {
          setState(() => _isPressed = false);
          widget.onTap!();
        }
      },
      onTapCancel: () {
        if (widget.onTap != null) setState(() => _isPressed = false);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _isPressed ? 4.0 : 0.0, 0),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20.r),
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withValues(alpha: isDark ? 0.30 : 0.18),
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
          child: Container(
            // Outer Gold Frame Gradient
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20.r),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _goldLight.withValues(alpha: 0.85),
                  _goldPrimary,
                  _goldDark,
                ],
              ),
            ),
            padding: EdgeInsets.all(2.r),
            child: Container(
              padding: EdgeInsets.all(context.rw(18)),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18.r),
                color: scheme.surface,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    scheme.surface,
                    Color.lerp(scheme.surface, scheme.primary, 0.04)!,
                  ],
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18.r),
                child: Stack(
                  children: [
                    // Corner Decorative Accents
                    Positioned(
                      top: -16.r,
                      left: -16.r,
                      child: _TraditionalCornerOrnament(color: scheme.primary),
                    ),
                    Positioned(
                      bottom: -16.r,
                      right: -16.r,
                      child: Transform.rotate(
                        angle: 3.14159,
                        child:
                            _TraditionalCornerOrnament(color: scheme.primary),
                      ),
                    ),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header with Title & Animated View KPI Tag
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  // Embossed Calendar Medallion
                                  Container(
                                    width: 36.r,
                                    height: 36.r,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          scheme.primary
                                              .withValues(alpha: 0.22),
                                          scheme.primary
                                              .withValues(alpha: 0.06),
                                        ],
                                      ),
                                      border: Border.all(
                                        color:
                                            _goldPrimary.withValues(alpha: 0.7),
                                        width: 1.2,
                                      ),
                                    ),
                                    child: Center(
                                      // Drawn, not a glyph: the medallion now
                                      // shows a month filling in and a day
                                      // being marked, which is what the card
                                      // is about. See CalendarMonthIcon.
                                      child: CalendarMonthIcon(
                                        size: 20.r,
                                        accent: scheme.primary,
                                        ink: scheme.onSurface
                                            .withValues(alpha: 0.70),
                                        muted: scheme.onSurface
                                            .withValues(alpha: 0.30),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 10.w),
                                  Flexible(
                                    child: Text(
                                      'shell.monthly_target'.trParams(
                                          {'month': widget.monthName}),
                                      style: TextStyle(
                                        color: scheme.onSurface,
                                        fontSize: context.rsp(14),
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.2,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Row(
                              children: [
                                Icon(
                                  Icons.bar_chart_rounded,
                                  size: 14.sp,
                                  color: scheme.primary,
                                ),
                                SizedBox(width: 4.w),
                                Text(
                                  'home.view_kpi'.tr,
                                  style: TextStyle(
                                    color: scheme.primary,
                                    fontSize: context.rsp(11),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                // The AnimatedBuilder belongs here, on the
                                // only thing that reads the animation. It used
                                // to wrap the percentage pill — whose builder
                                // never touched the value — so the pill
                                // repainted a gradient and shadow every frame
                                // for nothing while this arrow, sampling
                                // `.value` with no listener, never moved at
                                // all.
                                AnimatedBuilder(
                                  animation: _slideAnimation,
                                  // The icon is identical every frame; only
                                  // its offset changes. Built once and passed
                                  // through, so the rebuild is a translation
                                  // and not an Icon reconstruction.
                                  child: Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 10.sp,
                                    color: scheme.primary,
                                  ),
                                  builder: (context, child) =>
                                      Transform.translate(
                                    offset: Offset(
                                        reduceMotion
                                            ? 0
                                            : _slideAnimation.value,
                                        0),
                                    child: child,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        SizedBox(height: context.rh(14)),

                        // Values Display & Clickable Visual Hint
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // Shrinks rather than overflows: a seven-digit
                            // target with its thousands separators, or large
                            // system text, is wider than the space beside the
                            // percentage pill.
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      _dollars(context, widget.achievedAmount),
                                      style: TextStyle(
                                        color: scheme.onSurface,
                                        fontSize: context.rsp(24),
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    SizedBox(width: 6.w),
                                    Text(
                                      '/ ${_dollars(context, widget.targetAmount)}',
                                      style: TextStyle(
                                        color: scheme.onSurface
                                            .withValues(alpha: 0.5),
                                        fontSize: context.rsp(14),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(width: 8.w),

                            // Explicit "View KPI" interactive affordance pill
                            if (widget.onTap != null)
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12.w,
                                  vertical: 4.h,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      appColors.success,
                                      Color.lerp(
                                        appColors.success,
                                        _goldDark,
                                        0.25,
                                      )!,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(20.r),
                                  boxShadow: [
                                    BoxShadow(
                                      color: appColors.success
                                          .withValues(alpha: 0.35),
                                      offset: const Offset(0, 2),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: Text(
                                  '$_percentage%',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: context.rsp(12),
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                          ],
                        ),

                        SizedBox(height: context.rh(14)),

                        // Progress Track
                        Container(
                          height: context.rh(12),
                          decoration: BoxDecoration(
                            color: appColors.surfaceSoft,
                            borderRadius: BorderRadius.circular(10.r),
                            border: Border.all(
                              color: _goldPrimary.withValues(alpha: 0.25),
                              width: 1,
                            ),
                          ),
                          child: Stack(
                            children: [
                              FractionallySizedBox(
                                widthFactor: _progress,
                                child: Container(
                                  height: context.rh(12),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        appColors.success
                                            .withValues(alpha: 0.85),
                                        appColors.success,
                                        Color.lerp(
                                          appColors.success,
                                          _goldDark,
                                          0.3,
                                        )!,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(10.r),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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

class _TraditionalCornerOrnament extends StatelessWidget {
  const _TraditionalCornerOrnament({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40.r,
      height: 40.r,
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
