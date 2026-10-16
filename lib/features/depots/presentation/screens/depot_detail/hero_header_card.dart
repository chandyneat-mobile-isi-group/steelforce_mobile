part of '../depot_detail_screen.dart';

class _HeroHeaderCard extends StatefulWidget {
  const _HeroHeaderCard({
    required this.depot,
    required this.onPhoneTap,
    required this.onLocationTap,
  });

  final Depot depot;
  final Function(String) onPhoneTap;
  final Function(double, double) onLocationTap;

  @override
  State<_HeroHeaderCard> createState() => _HeroHeaderCardState();
}

class _HeroHeaderCardState extends State<_HeroHeaderCard> {
  final GlobalKey _cardKey = GlobalKey();

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
    } catch (_) {
      // A raw exception never reaches the screen.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('depots.detail.capture_failed'.tr)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final depot = widget.depot;

    final phoneNum = depot.phone.isNotEmpty ? depot.phone : _fallbackPhone;
    final latitude = depot.hasCoordinates ? depot.latitude : _fallbackLatitude;
    final longitude =
        depot.hasCoordinates ? depot.longitude : _fallbackLongitude;
    final outletTier = (depot.priceGroup?.isNotEmpty ?? false)
        ? depot.priceGroup!
        : _fallbackOutletTier;

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
                        context.localized(depot.displayName),
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
                              label: outletTier,
                              color: scheme.primary.withValues(alpha: 0.12),
                              textColor: scheme.primary),
                          SizedBox(width: context.rw(6)),
                          Text(
                            depot.sapDepotId?.isNotEmpty == true
                                ? depot.sapDepotId!
                                : _fallbackOutletId,
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: context.rsp(11),
                              fontWeight: FontWeight.w600,
                            ),
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
                _QuickActionButton(
                  icon: Icons.call_rounded,
                  label: 'depots.detail.call'.tr,
                  color: Colors.green,
                  onTap: () => widget.onPhoneTap(phoneNum),
                ),
                _QuickActionButton(
                  icon: Icons.directions_rounded,
                  label: 'depots.detail.map'.tr,
                  color: Colors.blue,
                  onTap: () => widget.onLocationTap(latitude, longitude),
                ),
                // HC Visit and Edit live in the app bar only; repeating
                // them here crowded the row.
                _QuickActionButton(
                  icon: Icons.camera_alt_outlined,
                  label: 'depots.detail.capture'.tr,
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
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(context.rr(8)),
      child: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: context.rw(8), vertical: context.rh(4)),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(context.rr(8)),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: context.rr(18)),
            ),
            SizedBox(height: context.rh(3)),
            Text(
              label,
              style: TextStyle(
                fontSize: context.rsp(11),
                color: context.appColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
