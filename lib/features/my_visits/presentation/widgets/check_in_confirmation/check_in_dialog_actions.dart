part of '../check_in_confirmation_dialog.dart';

class _Actions extends StatelessWidget {
  const _Actions({
    required this.phase,
    required this.accent,
    required this.onCancel,
    required this.onConfirm,
    required this.onWithReason,
    required this.onWithoutGps,
    required this.onRetry,
    required this.onOpenSettings,
  });

  final CheckInGpsPhase phase;
  final Color accent;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final VoidCallback onWithReason;
  final VoidCallback onWithoutGps;
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    // (label, icon, onTap, colour) for the full-width primary; null → a
    // disabled "Locating…" placeholder that keeps the layout from jumping.
    final (String, IconData, VoidCallback, Color)? primary = switch (phase) {
      CheckInGpsPhase.searching => null,
      CheckInGpsPhase.within || CheckInGpsPhase.noOutlet => (
          'my_visits.check_in_verification.confirm'.tr,
          Icons.check_rounded,
          onConfirm,
          colors.success,
        ),
      CheckInGpsPhase.weakSignal || CheckInGpsPhase.outside => (
          'my_visits.check_in_verification.continue_with_reason'.tr,
          Icons.edit_note_rounded,
          onWithReason,
          accent,
        ),
      CheckInGpsPhase.unavailable => (
          _Copy.withoutGps,
          Icons.edit_location_alt_rounded,
          onWithoutGps,
          accent,
        ),
      CheckInGpsPhase.servicesDisabled => (
          _Copy.turnOn,
          Icons.location_on_rounded,
          onOpenSettings,
          scheme.primary,
        ),
      CheckInGpsPhase.permissionDenied => (
          _Copy.allow,
          Icons.my_location_rounded,
          onOpenSettings,
          scheme.primary,
        ),
      CheckInGpsPhase.permissionDeniedForever => (
          _Copy.openSettings,
          Icons.settings_rounded,
          onOpenSettings,
          scheme.primary,
        ),
    };

    final String? secondaryLabel = switch (phase) {
      CheckInGpsPhase.unavailable => _Copy.tryAgain,
      CheckInGpsPhase.outside || CheckInGpsPhase.weakSignal => _Copy.refresh,
      _ => null,
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PressableScale(
          enabled: primary != null,
          child: SizedBox(
            height: context.rh(50),
            child: ElevatedButton(
              onPressed: primary?.$3,
              style: ElevatedButton.styleFrom(
                backgroundColor: primary?.$4 ?? scheme.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: scheme.primary.withValues(alpha: 0.10),
                disabledForegroundColor: scheme.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(context.rr(14)),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (primary == null)
                    SizedBox(
                      width: context.rr(16),
                      height: context.rr(16),
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: scheme.primary,
                      ),
                    )
                  else
                    Icon(primary.$2, size: context.rr(19)),
                  SizedBox(width: context.rw(8)),
                  Flexible(
                    child: Text(
                      primary?.$1 ?? _Copy.locating,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: context.rsp(14.5),
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(height: context.rh(6)),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: onCancel,
              style: TextButton.styleFrom(
                foregroundColor: colors.textSecondary,
                padding: EdgeInsets.symmetric(
                    horizontal: context.rw(18), vertical: context.rh(10)),
              ),
              child: Text('common.cancel'.tr,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            if (secondaryLabel != null) ...[
              Container(
                width: 1,
                height: context.rh(16),
                color: colors.border,
              ),
              TextButton.icon(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  foregroundColor: scheme.primary,
                  padding: EdgeInsets.symmetric(
                      horizontal: context.rw(18), vertical: context.rh(10)),
                ),
                icon: Icon(Icons.refresh_rounded, size: context.rr(17)),
                label: Text(secondaryLabel,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Shrinks slightly under the finger and springs back — the tactile cue that
/// a tap registered, before the dialog closes.
class _PressableScale extends StatefulWidget {
  const _PressableScale({required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  State<_PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<_PressableScale> {
  bool _down = false;

  void _set(bool down) {
    if (!widget.enabled || _down == down) return;
    setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? 0.97 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
