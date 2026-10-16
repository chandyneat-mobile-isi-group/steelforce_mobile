import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

/// Quick-action row on the depot detail screen. Purely presentational — the
/// actual navigation/side-effects live in the parent callbacks; this widget
/// adds the tactile layer (press-scale, colour/shadow transitions, haptics) so
/// those transitions feel smooth and responsive.
class DepotQuickActions extends StatelessWidget {
  const DepotQuickActions({
    super.key,
    required this.onCall,
    required this.onCreateOpportunity,
    required this.onLogVisit,
    required this.onAddNote,
  });

  final VoidCallback onCall;
  final VoidCallback onCreateOpportunity;
  final VoidCallback onLogVisit;
  final VoidCallback onAddNote;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: _PrimaryAction(
            icon: Icons.trending_up_rounded,
            label: 'depots.create_opportunity'.tr,
            onTap: onCreateOpportunity,
          ),
        ),
        SizedBox(width: context.rw(8)),
        _IconAction(
          icon: Icons.call_rounded,
          label: 'depots.call'.tr,
          onTap: onCall,
        ),
        SizedBox(width: context.rw(8)),
        _IconAction(
          icon: Icons.pin_drop_rounded,
          label: 'depots.visit'.tr,
          onTap: onLogVisit,
        ),
        SizedBox(width: context.rw(8)),
        _IconAction(
          icon: Icons.note_add_rounded,
          label: 'depots.note'.tr,
          onTap: onAddNote,
        ),
      ],
    );
  }
}

/// Gradient primary CTA with a lift shadow that presses in on tap.
class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    return _Pressable(
      onTap: onTap,
      scale: 0.97,
      builder: (context, pressed) => AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [scheme.primary, colors.primaryHover],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: pressed
              ? const []
              : [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: context.rr(18), color: scheme.onPrimary),
            SizedBox(width: context.rw(6)),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: scheme.onPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: context.rsp(12.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact icon tile whose border/fill/icon animate to the brand colour while
/// pressed, giving clear tactile feedback before the action fires.
class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    return _Pressable(
      onTap: onTap,
      builder: (context, pressed) {
        final accent = pressed ? scheme.primary : colors.textSecondary;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          width: 54,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: pressed ? colors.surfaceStrong : colors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: pressed ? scheme.primary : colors.border,
              width: pressed ? 1.4 : 1,
            ),
            boxShadow: pressed ? const [] : colors.cardShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: pressed ? 1.12 : 1.0,
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                child: Icon(icon, color: scheme.primary, size: context.rr(18)),
              ),
              SizedBox(height: context.rh(3)),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 160),
                style: TextStyle(
                  color: accent,
                  fontSize: context.rsp(9.5),
                  fontWeight: FontWeight.w700,
                ),
                child: Text(label),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Reusable press-to-scale wrapper: animates a subtle scale-down on tap-down,
/// fires a selection haptic, and exposes the pressed state to its [builder] so
/// children can animate colour/shadow in sync. Keeps every quick action's
/// interaction identical without repeating gesture/animation plumbing.
class _Pressable extends StatefulWidget {
  const _Pressable({
    required this.onTap,
    required this.builder,
    this.scale = 0.94,
  });

  final VoidCallback onTap;
  final Widget Function(BuildContext context, bool pressed) builder;
  final double scale;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.builder(context, _pressed),
      ),
    );
  }
}
