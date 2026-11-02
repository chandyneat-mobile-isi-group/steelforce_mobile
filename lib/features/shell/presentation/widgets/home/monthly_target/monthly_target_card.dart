/// Home "Monthly Target" card: press handling, the KPI-arrow animation and
/// progress maths. Look is in monthly_target_frame / _header / _amounts / _progress_bar.
library;

import 'package:flutter/material.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/features/shell/presentation/widgets/home/monthly_target/monthly_target_amounts.dart';
import 'package:steelforce/features/shell/presentation/widgets/home/monthly_target/monthly_target_frame.dart';
import 'package:steelforce/features/shell/presentation/widgets/home/monthly_target/monthly_target_header.dart';
import 'package:steelforce/features/shell/presentation/widgets/home/monthly_target/monthly_target_progress_bar.dart';

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
  // Style constants (design units unless noted).
  static const double _rowGap = 14;
  static const Duration _pressDuration = Duration(milliseconds: 100);
  static const double _pressDrop = 4.0; // logical px the card sinks on press
  static const Duration _arrowPeriod = Duration(milliseconds: 1400);
  static const double _arrowDrift = 4.0; // logical px the KPI arrow travels

  bool _isPressed = false;
  late final AnimationController _pulseController;
  late final Animation<double> _slideAnimation;

  double get _progress => widget.targetAmount > 0
      ? (widget.achievedAmount / widget.targetAmount).clamp(0.0, 1.0)
      : 0.0;

  int get _percentage => (_progress * 100).round();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: _arrowPeriod,
    )..repeat(reverse: true);

    _slideAnimation = Tween<double>(begin: 0.0, end: _arrowDrift).animate(
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

  void _setPressed(bool pressed) {
    if (widget.onTap != null) setState(() => _isPressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    // FS-ANI-7. The new calendar icon honours this itself; the arrow's drift
    // is driven from here, so it has to be read at this level too.
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) {
        if (widget.onTap != null) {
          setState(() => _isPressed = false);
          widget.onTap!();
        }
      },
      onTapCancel: () => _setPressed(false),
      child: AnimatedContainer(
        duration: _pressDuration,
        curve: Curves.easeOut,
        transform:
            Matrix4.translationValues(0, _isPressed ? _pressDrop : 0.0, 0),
        child: MonthlyTargetFrame(
          isPressed: _isPressed,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              MonthlyTargetHeader(
                monthName: widget.monthName,
                slideAnimation: _slideAnimation,
                reduceMotion: reduceMotion,
              ),
              SizedBox(height: context.rh(_rowGap)),
              MonthlyTargetAmounts(
                achievedAmount: widget.achievedAmount,
                targetAmount: widget.targetAmount,
                percentage: _percentage,
                showPercentage: widget.onTap != null,
              ),
              SizedBox(height: context.rh(_rowGap)),
              MonthlyTargetProgressBar(progress: _progress),
            ],
          ),
        ),
      ),
    );
  }
}
