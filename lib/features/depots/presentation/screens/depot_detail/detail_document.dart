part of '../depot_detail_screen.dart';

/// Marks a subtree as the saved document rather than the live screen: tiles
/// print their whole value and nothing looks tappable.
class _DocumentMode extends InheritedWidget {
  const _DocumentMode({required super.child});

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_DocumentMode>() != null;

  @override
  bool updateShouldNotify(_DocumentMode oldWidget) => false;
}

/// Everything the details screen knows about [depot] on one page, in the
/// order of its sections — what the Capture button saves to the photos.
class _DepotDocument extends StatelessWidget {
  const _DepotDocument({
    required this.depot,
    required this.printedAt,
    this.watermark,
  });

  final Depot depot;
  final DateTime printedAt;

  /// The ISI Steel logo across the middle; none when it failed to load.
  final PictureInfo? watermark;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final profile = depot.profile;
    void noPhone(String _) {}
    void noMap(double _, double __) {}
    return _DocumentMode(
      child: Material(
        color: colors.canvas,
        child: CustomPaint(
          foregroundPainter:
              watermark == null ? null : _WatermarkPainter(watermark!),
          child: Padding(
            padding: EdgeInsets.all(context.rr(16)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DocumentHeader(depot: depot, printedAt: printedAt),
                _DocumentHeading('depots.detail.group_depot_info'.tr),
                _DepotFactsSection(
                    depot: depot, onPhoneTap: noPhone, onLocationTap: noMap),
                _FieldFactsSection(profile),
                _ManagementSection(profile),
                _SuppliersSection(profile),
                _DocumentHeading('depots.detail.group_sales_contacts'.tr),
                _DocumentHeading('depots.detail.section_sales'.tr, sub: true),
                _SalesAreasSection(depot: depot, financial: false),
                _SalesTeamSection(depot),
                _DocumentHeading('depots.detail.section_financial'.tr,
                    sub: true),
                _SalesAreasSection(depot: depot, financial: true),
                _DocumentHeading('depots.detail.section_contact_audit'.tr,
                    sub: true),
                _ContactsSection(depot: depot, onPhoneTap: noPhone),
                _AuditSection(depot),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The title band: what this is, whose it is, and when it was made.
class _DocumentHeader extends StatelessWidget {
  const _DocumentHeader({required this.depot, required this.printedAt});

  final Depot depot;
  final DateTime printedAt;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onBand = scheme.onPrimary;
    TextStyle style(double size, FontWeight weight, {double alpha = 1}) =>
        TextStyle(
          color: onBand.withValues(alpha: alpha),
          fontSize: context.rsp(size),
          fontWeight: weight,
          height: 1.3,
        );
    final khName = depot.khName?.trim() ?? '';
    return Container(
      padding: EdgeInsets.all(context.rr(16)),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(context.rr(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('depots.detail.document_title'.tr.toUpperCase(),
              style: style(11, FontWeight.w800, alpha: 0.8)),
          SizedBox(height: context.rh(6)),
          Text(_orNull(depot.enName ?? depot.shopName),
              style: style(19, FontWeight.w900)),
          if (khName.isNotEmpty)
            Text(khName, style: style(14, FontWeight.w700)),
          SizedBox(height: context.rh(10)),
          Wrap(
            spacing: context.rw(6),
            runSpacing: context.rh(6),
            children: [
              for (final label in [
                _orNull(depot.sapDepotId ?? depot.depotCode),
                _orNull(_typeLabel(depot.depotType)),
                depot.status.apiValue,
                if (depot.profile?.tier?.trim().isNotEmpty ?? false)
                  depot.profile!.tier!,
              ])
                _PillBadge(
                  label: label,
                  color: onBand.withValues(alpha: 0.16),
                  textColor: onBand,
                ),
            ],
          ),
          SizedBox(height: context.rh(10)),
          Text(
            'depots.detail.document_generated'.trParams(
                {'date': DateFormat('yyyy-MM-dd HH:mm').format(printedAt)}),
            style: style(11, FontWeight.w600, alpha: 0.8),
          ),
        ],
      ),
    );
  }
}

/// A category or section title between the cards.
class _DocumentHeading extends StatelessWidget {
  const _DocumentHeading(this.text, {this.sub = false});

  final String text;
  final bool sub;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: EdgeInsets.only(
          top: context.rh(sub ? 2 : 16), bottom: context.rh(sub ? 6 : 8)),
      child: Text(
        sub ? text : text.toUpperCase(),
        style: TextStyle(
          color: sub
              ? colors.textSecondary
              : Theme.of(context).colorScheme.primary,
          fontSize: context.rsp(sub ? 12.5 : 13),
          fontWeight: FontWeight.w900,
          letterSpacing: sub ? 0 : 0.6,
        ),
      ),
    );
  }
}
