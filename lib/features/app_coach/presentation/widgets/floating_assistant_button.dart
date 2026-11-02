import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/shared/animations/coach_mascot.dart';

/// The floating coach mascot. Tapping it calls [onResume] — resume a
/// paused walkthrough, or open the lessons; it stays clear of the bottom
/// inset and is fully labelled for screen readers.
class FloatingAssistantButton extends StatefulWidget {
  const FloatingAssistantButton({
    super.key,
    required this.onResume,
    this.semanticsLabelKey = 'coach.resume_hint',
  });

  final VoidCallback onResume;

  /// Localization key read out by screen readers.
  final String semanticsLabelKey;

  @override
  State<FloatingAssistantButton> createState() =>
      _FloatingAssistantButtonState();
}

class _FloatingAssistantButtonState extends State<FloatingAssistantButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bottomInset = media.padding.bottom;

    // Self-positioning within a full-size parent so the host can drop it in
    // without a Stack wrapper. Keep the full mascot visible, like a sticker,
    // instead of enclosing it in a round icon button.
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: EdgeInsets.only(
          right: context.rw(12),
          bottom: context.rh(16) + bottomInset,
        ),
        child: Semantics(
          button: true,
          label: widget.semanticsLabelKey.tr,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.85, end: 1.0),
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutBack,
            builder: (_, entrance, child) => Transform.scale(
              scale: entrance * (_pressed ? 0.96 : 1.0),
              child: child,
            ),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticFeedback.mediumImpact();
                widget.onResume();
              },
              onTapDown: (_) => setState(() => _pressed = true),
              onTapCancel: () => setState(() => _pressed = false),
              onTapUp: (_) => setState(() => _pressed = false),
              child: CoachMascot(
                size: context.rh(84),
                animate: !media.disableAnimations,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
