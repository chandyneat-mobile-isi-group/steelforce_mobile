import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

/// A `[-]  n  [+]` quantity stepper with press-and-hold auto-repeat.
class QuantityStepper extends StatefulWidget {
  const QuantityStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 9999,
    this.step = 1,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final int step;

  @override
  State<QuantityStepper> createState() => _QuantityStepperState();
}

class _QuantityStepperState extends State<QuantityStepper> {
  Timer? _repeatTimer;

  @override
  void dispose() {
    _repeatTimer?.cancel();
    super.dispose();
  }

  void _apply(int delta) {
    final next = (widget.value + delta).clamp(widget.min, widget.max);
    if (next != widget.value) {
      HapticFeedback.selectionClick();
      widget.onChanged(next);
    }
  }

  void _startRepeat(int delta) {
    _repeatTimer?.cancel();
    int ms = 300;
    _repeatTimer = Timer.periodic(Duration(milliseconds: ms), (timer) {
      _apply(delta);
      if (ms > 60) {
        ms = (ms * 0.75).toInt();
        _repeatTimer?.cancel();
        _repeatTimer =
            Timer.periodic(Duration(milliseconds: ms), (t) => _apply(delta));
      }
    });
  }

  void _stopRepeat() => _repeatTimer?.cancel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canDecrement = widget.value > widget.min;
    final canIncrement = widget.value < widget.max;

    return Container(
      height: context.rh(46),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: context.appColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(
            icon: Icons.remove_rounded,
            enabled: canDecrement,
            onTap: () => _apply(-widget.step),
            onHoldStart: () => _startRepeat(-widget.step),
            onHoldEnd: _stopRepeat,
          ),
          Container(
            alignment: Alignment.center,
            constraints: const BoxConstraints(minWidth: 48),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '${widget.value}',
              style: TextStyle(
                fontSize: context.rsp(15),
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          _StepButton(
            icon: Icons.add_rounded,
            enabled: canIncrement,
            onTap: () => _apply(widget.step),
            onHoldStart: () => _startRepeat(widget.step),
            onHoldEnd: _stopRepeat,
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
    required this.onHoldStart,
    required this.onHoldEnd,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback onHoldStart;
  final VoidCallback onHoldEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onLongPressStart: enabled ? (_) => onHoldStart() : null,
      onLongPressEnd: enabled ? (_) => onHoldEnd() : null,
      onLongPressCancel: enabled ? onHoldEnd : null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: 44,
            height: context.rh(44),
            child: Icon(
              icon,
              size: context.rr(20),
              color: enabled
                  ? Theme.of(context).colorScheme.primary
                  : theme.disabledColor.withValues(alpha: 0.4),
            ),
          ),
        ),
      ),
    );
  }
}
