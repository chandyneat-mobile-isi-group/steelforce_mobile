part of '../stops_check_in_screen.dart';

class _CheckInBottomBar extends StatefulWidget {
  const _CheckInBottomBar({
    required this.enabled,
    required this.submitting,
    required this.hint,
    required this.onTap,
  });

  final bool enabled;
  final bool submitting;
  final String? hint;
  final VoidCallback onTap;

  @override
  State<_CheckInBottomBar> createState() => _CheckInBottomBarState();
}

class _CheckInBottomBarState extends State<_CheckInBottomBar> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!widget.enabled || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final enabled = widget.enabled;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              child: widget.hint == null
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: EdgeInsets.only(bottom: context.rh(8)),
                      child: Text(
                        widget.hint!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: context.rsp(11.5)),
                      ),
                    ),
            ),
            Listener(
              onPointerDown: (_) => _setPressed(true),
              onPointerUp: (_) => _setPressed(false),
              onPointerCancel: (_) => _setPressed(false),
              child: AnimatedScale(
                scale: _pressed ? 0.975 : 1,
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOut,
                child: SizedBox(
                  width: double.infinity,
                  height: context.rh(52),
                  child: ElevatedButton(
                    onPressed: enabled ? widget.onTap : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.success,
                      foregroundColor: scheme.onPrimary,
                      disabledBackgroundColor:
                          colors.success.withValues(alpha: 0.55),
                      disabledForegroundColor: scheme.onPrimary,
                      elevation: enabled && !_pressed ? 3 : 0,
                      shadowColor: colors.success.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          transitionBuilder: (child, a) =>
                              ScaleTransition(scale: a, child: child),
                          child: widget.submitting
                              ? SizedBox(
                                  key: const ValueKey('spin'),
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: scheme.onPrimary,
                                  ),
                                )
                              : Icon(
                                  Icons.check_circle_rounded,
                                  key: const ValueKey('icon'),
                                  size: context.rr(20),
                                ),
                        ),
                        SizedBox(width: context.rw(8)),
                        Text(
                          'my_visits.flow.checkin_continue'.tr,
                          style: TextStyle(
                            fontSize: context.rsp(15),
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
