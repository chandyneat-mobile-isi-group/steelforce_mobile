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
  /// True while a capture runs, so a second tap cannot start another.
  bool _capturing = false;

  /// Saves the whole depot — every section, not just this card — to the
  /// photos as one document image.
  Future<void> _captureDocument() async {
    setState(() => _capturing = true);
    final saved = await _saveDepotDocument(context, widget.depot);
    if (!mounted) return;
    setState(() => _capturing = false);
    if (saved) HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(saved
            ? 'depots.detail.document_saved'.tr
            : 'depots.detail.capture_failed'.tr),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final depot = widget.depot;

    final phoneNum = depot.contactPhone;
    final outletTier = _orNull(depot.profile?.tier);

    return Container(
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
                          _orNull(depot.sapDepotId ?? depot.depotCode),
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
                // No number, no call: dimmed rather than dialling nothing.
                onTap:
                    phoneNum.isEmpty ? null : () => widget.onPhoneTap(phoneNum),
              ),
              _QuickActionButton(
                icon: Icons.directions_rounded,
                label: 'depots.detail.map'.tr,
                color: Colors.blue,
                onTap: depot.hasCoordinates
                    ? () =>
                        widget.onLocationTap(depot.latitude, depot.longitude)
                    : null,
              ),
              // HC Visit and Edit live in the app bar only; repeating
              // them here crowded the row.
              _QuickActionButton(
                icon: Icons.camera_alt_outlined,
                label: 'depots.detail.capture'.tr,
                color: colors.textSecondary,
                onTap: _capturing ? null : _captureDocument,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
