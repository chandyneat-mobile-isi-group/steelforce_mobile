part of '../depot_detail_screen.dart';

/// The details screen's four sections. Each field of the depots API sits in
/// exactly one of them.
enum _DetailSection {
  general('depots.detail.section_general'),
  businessProfile('depots.detail.section_business_profile'),
  sales('depots.detail.section_sales'),
  financial('depots.detail.section_financial'),
  contactAudit('depots.detail.section_contact_audit');

  const _DetailSection(this.labelKey);

  final String labelKey;
}

/// Business Profile's three cards, picked one at a time.
enum _ProfilePart {
  fieldFacts('depots.detail.section_field_facts'),
  management('depots.detail.section_management'),
  suppliers('depots.detail.section_suppliers');

  const _ProfilePart(this.labelKey);

  final String labelKey;
}

/// The two categories the sections are filed under: what
/// the depot is, and who trades with it. The same for depots and Non-BP
/// depots — a section the API sent nothing for says so instead of vanishing.
enum _DetailGroup {
  depotInfo('depots.detail.group_depot_info',
      [_DetailSection.general, _DetailSection.businessProfile]),
  salesContacts('depots.detail.group_sales_contacts', [
    _DetailSection.sales,
    _DetailSection.financial,
    _DetailSection.contactAudit,
  ]);

  const _DetailGroup(this.labelKey, this.sections);

  final String labelKey;
  final List<_DetailSection> sections;
}

/// The category picker: full width and split evenly, so neither is ever off
/// screen. Labels wrap to two lines rather than truncate, which Khmer needs.
class _GroupSwitch extends StatelessWidget {
  const _GroupSwitch({required this.selected, required this.onChanged});

  final _DetailGroup selected;
  final ValueChanged<_DetailGroup> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    return Container(
      padding: EdgeInsets.all(context.rr(4)),
      decoration: BoxDecoration(
        color: colors.surfaceSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final group in _DetailGroup.values) ...[
              if (group != _DetailGroup.values.first)
                SizedBox(width: context.rw(4)),
              Expanded(
                child: Semantics(
                  button: true,
                  selected: group == selected,
                  child: Material(
                    color:
                        group == selected ? scheme.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        if (group == selected) return;
                        HapticFeedback.selectionClick();
                        onChanged(group);
                      },
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 44),
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: context.rw(6),
                              vertical: context.rh(8),
                            ),
                            child: Text(
                              group.labelKey.tr,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: group == selected
                                    ? scheme.onPrimary
                                    : colors.textSecondary,
                                fontSize: context.rsp(13),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
