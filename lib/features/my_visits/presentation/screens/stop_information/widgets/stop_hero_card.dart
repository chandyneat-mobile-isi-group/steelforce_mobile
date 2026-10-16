part of '../stop_information_screen.dart';

class _HeroCard extends StatefulWidget {
  const _HeroCard({
    required this.stop,
    required this.onPhoneTap,
    required this.onLocationTap,
  });

  final RouteStop stop;
  final Function(String) onPhoneTap;
  final Function(double, double) onLocationTap;

  @override
  State<_HeroCard> createState() => _HeroCardState();
}

class _HeroCardState extends State<_HeroCard> {
  final GlobalKey _cardKey = GlobalKey();

  /// Resolved once, not on every rebuild.
  ///
  /// `context.read` throws when the cubit was not provided, and doing that
  /// inside `build` meant constructing and catching an exception on every
  /// frame this card repainted. Null here means "no live position on this
  /// screen", which is a legitimate state — the distance pill is simply
  /// omitted rather than the card failing to render.
  LocationTrackingCubit? _locationCubit;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      _locationCubit = context.read<LocationTrackingCubit>();
    } on Object {
      _locationCubit = null;
    }
  }

  Future<void> _captureCard() async {
    try {
      final boundary =
          _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData?.buffer.asUint8List();

      if (pngBytes != null) {
        await Gal.putImageBytes(pngBytes);
        if (!mounted) return;
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('my_visits.screenshot_saved'.tr),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e, stack) {
      // The exception text never reaches the rep. It can carry a file path or
      // a platform message written for developers, and `flutter.md` §3 is
      // explicit that the user gets a useful human message while the technical
      // detail goes to the log (debug builds only).
      debugPrintStack(
          label: 'stopInformation.captureCard failed: $e', stackTrace: stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('my_visits.stop_info.screenshot_failed'.tr)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final c = widget.stop.depot;
    // The route sync's phone, or nothing — never the constant that used to
    // stand in for it.
    final phoneNum = _orDash(c.phone.isEmpty ? null : c.phone);

    return RepaintBoundary(
      key: _cardKey,
      child: Container(
        padding: EdgeInsets.all(context.rr(14)),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(context.rr(16)),
          border: Border.all(color: colors.border),
          boxShadow: colors.cardShadow,
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: context.rr(44),
                  height: context.rr(44),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(context.rr(10)),
                  ),
                  child: Icon(
                    Icons.storefront_rounded,
                    color: scheme.primary,
                    size: context.rr(22),
                  ),
                ),
                SizedBox(width: context.rw(12)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.localized(c.displayName),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: context.rsp(16),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: context.rh(2)),
                      Row(
                        children: [
                          _PillBadge(
                              label: 'Diamond',
                              color: scheme.primary.withValues(alpha: 0.12),
                              textColor: scheme.primary,
                              isExample: true),
                          SizedBox(width: context.rw(6)),
                          // Distance is only meaningful against a real pin.
                          // Measured against (0, 0) it read "10000.0 km" for
                          // every unmapped shop — a number the rep would
                          // reasonably read as the drive ahead of them.
                          if (c.hasCoordinates && _locationCubit != null)
                            BlocBuilder<LocationTrackingCubit,
                                LocationTrackingState>(
                              bloc: _locationCubit,
                              buildWhen: (a, b) => a.current != b.current,
                              builder: (context, state) {
                                final pos = state.current;
                                if (pos == null) return const SizedBox.shrink();
                                final dist = _formatDistance(
                                    GeofenceService.distanceMeters(
                                        pos.latitude,
                                        pos.longitude,
                                        c.latitude,
                                        c.longitude));
                                return _PillBadge(
                                  label: dist,
                                  color: Colors.green.shade100,
                                  textColor: Colors.green.shade900,
                                );
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: context.rh(12)),
            Divider(height: 1, color: colors.border.withValues(alpha: 0.5)),
            SizedBox(height: context.rh(8)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Both are disabled rather than hidden: the row is a fixed
                // three-action layout a rep learns by position, and Call
                // dialled the em dash placeholder while Map opened the
                // device's map app at (0, 0).
                _QuickActionButton(
                  icon: Icons.call_rounded,
                  label: 'my_visits.stop_info.action_call'.tr,
                  color: Colors.green,
                  onTap: phoneNum == _kNoValue
                      ? null
                      : () => widget.onPhoneTap(phoneNum),
                ),
                _QuickActionButton(
                  icon: Icons.directions_rounded,
                  label: 'my_visits.stop_info.action_map'.tr,
                  color: Colors.blue,
                  onTap: c.hasCoordinates
                      ? () => widget.onLocationTap(c.latitude, c.longitude)
                      : null,
                ),
                _QuickActionButton(
                  icon: Icons.camera_alt_outlined,
                  label: 'my_visits.stop_info.action_capture'.tr,
                  color: colors.textSecondary,
                  onTap: _captureCard,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDistance(double meters) {
    final km = meters / 1000;
    return km < 0.1 ? '${meters.round()} m' : '${km.toStringAsFixed(1)} km';
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;

  /// Null disables the action: it dims to the muted palette and stops
  /// responding, so an action with nothing behind it cannot be tapped.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final tint = enabled ? color : context.appColors.textHint;

    return InkWell(
      onTap: enabled
          ? () {
              HapticFeedback.lightImpact();
              onTap!();
            }
          : null,
      borderRadius: BorderRadius.circular(context.rr(8)),
      child: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: context.rw(16), vertical: context.rh(4)),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(context.rr(8)),
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: tint, size: context.rr(18)),
            ),
            SizedBox(height: context.rh(3)),
            Text(
              label,
              style: TextStyle(
                fontSize: context.rsp(11),
                color: enabled
                    ? context.appColors.textPrimary
                    : context.appColors.textHint,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
