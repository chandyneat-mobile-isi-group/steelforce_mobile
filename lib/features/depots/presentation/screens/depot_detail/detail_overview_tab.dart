part of '../depot_detail_screen.dart';

class _OverviewTab extends StatefulWidget {
  const _OverviewTab({
    required this.depot,
    required this.onPhoneTap,
    required this.onLocationTap,
  });

  final Depot depot;
  final Function(String) onPhoneTap;
  final Function(double, double) onLocationTap;

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  _DetailGroup _group = _DetailGroup.values.first;
  _DetailSection _section = _DetailGroup.values.first.sections.first;
  _ProfilePart _part = _ProfilePart.values.first;

  /// Every section opens on its top; Business Profile on Field Facts.
  void _open(_DetailSection s) => setState(() {
        _section = s;
        _part = _ProfilePart.values.first;
      });

  @override
  Widget build(BuildContext context) {
    final depot = widget.depot;
    final profile = depot.profile;
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
              context.pagePadding, context.rh(12), context.pagePadding, 0),
          child: _GroupSwitch(
            selected: _group,
            // Each group opens on its first section.
            onChanged: (g) {
              _group = g;
              _open(g.sections.first);
            },
          ),
        ),
        Padding(
          padding: EdgeInsets.only(top: context.rh(10)),
          child: _PillRow<_DetailSection>(
            items: _group.sections,
            labelKey: (s) => s.labelKey,
            selected: _section,
            onChanged: _open,
          ),
        ),
        if (_section == _DetailSection.businessProfile)
          Padding(
            padding: EdgeInsets.only(top: context.rh(8)),
            child: _PillRow<_ProfilePart>(
              items: _ProfilePart.values,
              labelKey: (p) => p.labelKey,
              selected: _part,
              onChanged: (p) => setState(() => _part = p),
              nested: true,
            ),
          ),
        Expanded(
          child: ListView(
            // A new key per section starts each one at the top.
            key: PageStorageKey((_section, _part)),
            padding: EdgeInsets.fromLTRB(
              context.pagePadding,
              context.rh(10),
              context.pagePadding,
              context.rh(20),
            ),
            children: [
              ..._spaced(
                  context,
                  switch (_section) {
                    _DetailSection.general => [
                        _DepotFactsSection(
                          depot: depot,
                          onPhoneTap: widget.onPhoneTap,
                          onLocationTap: widget.onLocationTap,
                        ),
                      ],
                    _DetailSection.sales => [
                        _SalesAreasSection(depot: depot, financial: false),
                        _SalesTeamSection(depot),
                      ],
                    _DetailSection.financial => [
                        _SalesAreasSection(depot: depot, financial: true),
                      ],
                    _DetailSection.businessProfile => [
                        switch (_part) {
                          _ProfilePart.fieldFacts =>
                            _FieldFactsSection(profile),
                          _ProfilePart.management =>
                            _ManagementSection(profile),
                          _ProfilePart.suppliers => _SuppliersSection(profile),
                        },
                      ],
                    _DetailSection.contactAudit => [
                        _ContactsSection(
                            depot: depot, onPhoneTap: widget.onPhoneTap),
                        _AuditSection(depot),
                      ],
                  }),
            ],
          ),
        ),
      ],
    );
  }
}

/// [cards] with a gap between each.
List<Widget> _spaced(BuildContext context, List<Widget> cards) => [
      for (final (i, card) in cards.indexed) ...[
        if (i > 0) SizedBox(height: context.rh(12)),
        card,
      ],
    ];
