import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

/// The small floating assistant shown while the coach is paused. Tapping it
/// resumes the walkthrough; it stays clear of the bottom inset and is fully
/// labelled for screen readers.
class FloatingAssistantButton extends StatefulWidget {
  const FloatingAssistantButton({super.key, required this.onResume});

  final VoidCallback onResume;

  @override
  State<FloatingAssistantButton> createState() =>
      _FloatingAssistantButtonState();
}

class _FloatingAssistantButtonState extends State<FloatingAssistantButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    // Reduced-motion is gated visually in build() (t collapses to 0), so it's
    // safe to always drive the controller here.
    _pulse.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final media = MediaQuery.of(context);
    final reduceMotion = media.disableAnimations;
    final bottomInset = media.padding.bottom;

    // Self-positioning within a full-size parent so the host can drop it in
    // without a Stack wrapper.
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: EdgeInsets.only(
            right: context.rw(16), bottom: context.rh(16) + bottomInset),
        child: Semantics(
          button: true,
          label: 'coach.resume_hint'.tr,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.5, end: 1.0),
            duration: const Duration(milliseconds: 420),
            curve: Curves.elasticOut,
            builder: (_, entrance, child) =>
                Transform.scale(scale: entrance, child: child),
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (_, child) {
                final t = reduceMotion ? 0.0 : _pulse.value;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Breathing halo — a quiet "look here" cue while idle.
                    Container(
                      width: context.rr(56) + 12 * t,
                      height: context.rr(56) + 12 * t,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scheme.primary.withValues(alpha: 0.16 * (1 - t)),
                      ),
                    ),
                    child!,
                  ],
                );
              },
              child: AnimatedScale(
                scale: _pressed ? 0.92 : 1.0,
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOut,
                child: Material(
                  color: scheme.primary,
                  shape: const CircleBorder(),
                  elevation: 8,
                  shadowColor: scheme.primary.withValues(alpha: 0.55),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      widget.onResume();
                    },
                    onHighlightChanged: (v) => setState(() => _pressed = v),
                    child: Padding(
                      padding: EdgeInsets.all(context.rr(14)),
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        color: scheme.onPrimary,
                        size: context.rr(24),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
