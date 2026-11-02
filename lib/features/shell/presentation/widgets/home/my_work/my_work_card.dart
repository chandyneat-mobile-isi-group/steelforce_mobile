/// One pressable My Work tile on Home: 3D press-down, accent shadow, steel
/// gradient frame and optional badge. Inner content is in my_work_card_face.
library;

import 'package:flutter/material.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/app_colors.dart';
import 'package:steelforce/features/shell/presentation/widgets/home/my_work/my_work_badge.dart';
import 'package:steelforce/features/shell/presentation/widgets/home/my_work/my_work_card_face.dart';
import 'package:steelforce/shared/animations/work_icons.dart';

class MyWorkCard extends StatefulWidget {
  const MyWorkCard({
    super.key,
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
  State<MyWorkCard> createState() => _MyWorkCardState();
}

class _MyWorkCardState extends State<MyWorkCard> {
  // Style constants (design units unless noted).
  static const double _radius = 20;
  static const double _frameWidth = 2;
  static const double _badgeInset = 8;
  static const Duration _pressDuration = Duration(milliseconds: 100);
  static const double _pressDrop = 4.0; // logical px the card sinks on press

  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final depthOffset = _isPressed ? 2.0 : 6.0;
    final radius = BorderRadius.circular(context.rr(_radius));

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: _pressDuration,
        curve: Curves.easeOut,
        transform:
            Matrix4.translationValues(0, _isPressed ? _pressDrop : 0.0, 0),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: radius,
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
              // 1. Outer steel frame & card base
              Container(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.steelLight,
                      AppColors.steelRim,
                      AppColors.steelLight,
                    ],
                  ),
                ),
                padding: EdgeInsets.all(context.rr(_frameWidth)),
                child: MyWorkCardFace(
                  label: widget.label,
                  accent: widget.accent,
                  kind: widget.kind,
                  tileHeight: widget.tileHeight,
                ),
              ),

              // 3. Badge with 3D Elevation
              if (widget.badgeText != null)
                Positioned(
                  top: context.rh(_badgeInset),
                  right: context.rw(_badgeInset),
                  child: MyWorkBadge(text: widget.badgeText!),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
