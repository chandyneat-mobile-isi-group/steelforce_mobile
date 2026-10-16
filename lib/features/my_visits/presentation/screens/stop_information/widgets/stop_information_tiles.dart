part of '../stop_information_screen.dart';

/// The loaded outlet profile, or null when there is none *yet* — and also
/// when no [StopInformationCubit] was provided at all.
///
/// Tolerating an absent provider is deliberate. This cubit *enriches* the
/// screen; it does not constitute it. The route sync has already supplied the
/// name, pin and geofence, so a screen opened without the provider — a widget
/// test, or a future entry point that forgets it — must still render rather
/// than throw a `ProviderNotFoundException` at a rep standing outside a shop.
///
/// `watch`, so the tabs rebuild when the fetch lands.
DepotStopInformation? _stopInformationOf(BuildContext context) {
  try {
    final state = context.watch<StopInformationCubit>().state;
    return state is StopInformationReady ? state.information : null;
  } on Object {
    return null;
  }
}

/// The enrichment fetch's state, or null when no cubit was provided.
///
/// Same tolerance as [_stopInformationOf], and the reason the banner below can
/// be dropped into a screen that may not have the cubit at all.
StopInformationState? _stopInformationStateOf(BuildContext context) {
  try {
    return context.watch<StopInformationCubit>().state;
  } on Object {
    return null;
  }
}

/// Says whether the outlet details are still arriving, or did not arrive.
///
/// Without this every unloaded field renders as an em dash, which is the same
/// thing the screen shows for "the shop genuinely has no telegram handle". A
/// rep cannot tell a failed fetch from an empty record, and the screen has no
/// loading state at all — it renders a full card of dashes the instant it
/// opens. `flutter.md` §3 requires the four states to be distinguishable, and
/// these two were collapsed into Success.
///
/// Deliberately a slim banner rather than a blocking spinner or an error
/// screen: the route sync has already supplied the name, pin and geofence, and
/// a rep standing outside a shop needs those far more than a credit limit.
class _DetailsStatusBanner extends StatelessWidget {
  const _DetailsStatusBanner();

  @override
  Widget build(BuildContext context) {
    final state = _stopInformationStateOf(context);
    if (state == null || state is StopInformationReady) {
      return const SizedBox.shrink();
    }

    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final loading = state is StopInformationLoading;
    // Offline is a normal condition, not a failure (ADR-0002 §4), so it gets
    // the neutral treatment rather than the error palette.
    final offline = state is StopInformationUnavailable && state.isOffline;
    final tint = loading || offline ? colors.textSecondary : scheme.error;

    final label = switch (state) {
      StopInformationLoading() => 'my_visits.stop_info.details_loading'.tr,
      StopInformationUnavailable(isOffline: true) =>
        'my_visits.stop_info.details_offline'.tr,
      _ => 'my_visits.stop_info.details_unavailable'.tr,
    };

    return Padding(
      padding: EdgeInsets.only(bottom: context.rh(10)),
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: context.rw(12), vertical: context.rh(9)),
        decoration: BoxDecoration(
          color: tint.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(context.rr(12)),
        ),
        child: Row(
          children: [
            if (loading)
              SizedBox(
                width: context.rr(13),
                height: context.rr(13),
                child: CircularProgressIndicator(strokeWidth: 2, color: tint),
              )
            else
              Icon(
                offline ? Icons.cloud_off_rounded : Icons.error_outline_rounded,
                size: context.rr(15),
                color: tint,
              ),
            SizedBox(width: context.rw(9)),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: tint,
                  fontSize: context.rsp(11.5),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Marks a value as an illustrative example rather than data.
class _ExampleChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.rw(6),
        vertical: context.rh(1),
      ),
      decoration: BoxDecoration(
        color: colors.textSecondary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        'my_visits.stop_info.example'.tr,
        style: TextStyle(
          color: colors.textSecondary,
          fontSize: context.rsp(9),
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// What to show when neither the stop-information call nor the route sync has
/// a value.
///
/// An em dash, never an invented one. The eight values this screen used to
/// hardcode are exactly why: a placeholder that looks like data is worse than
/// a blank, because a rep will read it out.
const String _kNoValue = '\u2014';

String _orDash(String? value) {
  final v = value?.trim();
  return (v == null || v.isEmpty) ? _kNoValue : v;
}

/// `$50,000` / `៛200,000`, from a `{amount, currency}` pair.
///
/// Rendering an amount without its currency is a 4000× error waiting to happen
/// in front of an outlet owner, so the currency is never dropped.
String _money(Money? money) {
  if (money == null) return _kNoValue;
  return NumberFormat.simpleCurrency(name: money.currency).format(money.amount);
}

class _CompactTile extends StatelessWidget {
  const _CompactTile({
    required this.icon,
    required this.label,
    required this.value,
    this.last = false,
    this.onTap,
    this.isExample = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool last;
  final VoidCallback? onTap;

  /// Renders the value as a plainly-marked example rather than as data.
  ///
  /// Five figures on this screen have no source in any system yet — each is
  /// blocked on a business rule nobody has decided (OBD-1, -2, -3, -6). A rep
  /// quoting "\$50,000 credit limit" to an outlet owner from a constant is
  /// worse than showing nothing, so these are italic, muted and chipped: the
  /// chip is what lets a rep tell at a glance which figures are real.
  ///
  /// See `docs/feature/depot/mobile/backend-change-notice.md` §4.
  final bool isExample;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return InkWell(
      onTap: onTap != null
          ? () {
              HapticFeedback.selectionClick();
              onTap!();
            }
          : null,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: context.rh(9)),
        decoration: BoxDecoration(
          border: last
              ? null
              : Border(bottom: BorderSide(color: colors.border, width: 0.5)),
        ),
        child: Row(
          children: [
            Icon(icon, size: context.rr(18), color: colors.textSecondary),
            SizedBox(width: context.rw(10)),
            Text(
              label,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: context.rsp(12),
              ),
            ),
            SizedBox(width: context.rw(10)),
            if (isExample) ...[
              _ExampleChip(),
              SizedBox(width: context.rw(6)),
            ],
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isExample
                      ? colors.textSecondary
                      : onTap != null
                          ? Theme.of(context).colorScheme.primary
                          : colors.textPrimary,
                  fontSize: context.rsp(12.5),
                  fontWeight: isExample ? FontWeight.w500 : FontWeight.w700,
                  fontStyle: isExample ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ),
            if (onTap != null) ...[
              SizedBox(width: context.rw(4)),
              Icon(Icons.chevron_right_rounded,
                  size: context.rr(16), color: colors.textSecondary),
            ],
          ],
        ),
      ),
    );
  }
}

class _PillBadge extends StatelessWidget {
  const _PillBadge({
    required this.label,
    required this.color,
    required this.textColor,
    this.isExample = false,
  });

  final String label;
  final Color color;
  final Color textColor;

  /// Renders the badge italic and muted and hangs an [_ExampleChip] beside it.
  ///
  /// Same treatment as `_CompactTile.isExample`, for the same reason: a rep
  /// must be able to tell at a glance which figures are real. See
  /// `docs/feature/depot/mobile/backend-change-notice.md` §4.
  final bool isExample;

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.rw(8),
        vertical: context.rh(3),
      ),
      decoration: BoxDecoration(
        color: isExample ? color.withValues(alpha: 0.06) : color,
        borderRadius: BorderRadius.circular(context.rr(6)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isExample ? context.appColors.textSecondary : textColor,
          fontSize: context.rsp(10.5),
          fontWeight: isExample ? FontWeight.w600 : FontWeight.w800,
          fontStyle: isExample ? FontStyle.italic : FontStyle.normal,
        ),
      ),
    );
    if (!isExample) return badge;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        badge,
        SizedBox(width: context.rw(4)),
        _ExampleChip(),
      ],
    );
  }
}
