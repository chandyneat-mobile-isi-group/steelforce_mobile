part of '../non_bp_depot_register_screen.dart';

/// Shows the chosen SAP depot, or invites the rep to pick one.
class _LinkedDepotField extends StatelessWidget {
  const _LinkedDepotField({
    required this.depot,
    required this.showError,
    required this.onTap,
  });

  final LinkableDepotDemo? depot;
  final bool showError;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final chosen = depot;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.all(context.rr(14)),
            decoration: BoxDecoration(
              color: colors.surfaceSoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: showError ? scheme.error : colors.border,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.link_rounded,
                  size: context.rr(18),
                  color: chosen == null ? colors.textSecondary : scheme.primary,
                ),
                SizedBox(width: context.rw(10)),
                Expanded(
                  child: chosen == null
                      ? Text(
                          'Choose a depot',
                          style: TextStyle(
                            fontSize: context.rsp(14),
                            color: scheme.onSurface.withValues(alpha: 0.35),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              chosen.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: context.rsp(14),
                                fontWeight: FontWeight.w700,
                                color: colors.textPrimary,
                              ),
                            ),
                            SizedBox(height: context.rh(2)),
                            Text(
                              '${chosen.code} · ${chosen.territory}',
                              style: TextStyle(
                                fontSize: context.rsp(11.5),
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: context.rr(20),
                  color: colors.textSecondary,
                ),
              ],
            ),
          ),
        ),
        if (showError) ...[
          SizedBox(height: context.rh(6)),
          Text(
            'Pick the depot this party buys through',
            style: TextStyle(
              fontSize: context.rsp(11),
              color: scheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

/// Bottom sheet listing the SAP depots a non-bp-depot can point at.
class _LinkedDepotPicker extends StatefulWidget {
  const _LinkedDepotPicker();

  @override
  State<_LinkedDepotPicker> createState() => _LinkedDepotPickerState();
}

class _LinkedDepotPickerState extends State<_LinkedDepotPicker> {
  String _query = '';

  List<LinkableDepotDemo> get _results {
    final term = _query.trim().toLowerCase();
    if (term.isEmpty) return demoLinkableDepots;

    return demoLinkableDepots
        .where(
          (c) =>
              c.name.toLowerCase().contains(term) ||
              c.code.toLowerCase().contains(term),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final results = _results;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.72,
      ),
      decoration: BoxDecoration(
        color: colors.canvas,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: context.rh(10)),
          Container(
            width: context.rw(40),
            height: context.rh(4),
            decoration: BoxDecoration(
              color: colors.border,
              borderRadius: BorderRadius.circular(100),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              context.rw(16),
              context.rh(16),
              context.rw(16),
              context.rh(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Link to depot',
                  style: TextStyle(
                    fontSize: context.rsp(16),
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                  ),
                ),
                SizedBox(height: context.rh(12)),
                TextField(
                  autofocus: false,
                  onChanged: (value) => setState(() => _query = value),
                  style: TextStyle(
                    fontSize: context.rsp(14),
                    color: colors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search name or code',
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      size: context.rr(18),
                      color: colors.textSecondary,
                    ),
                    hintStyle: TextStyle(
                      color: scheme.onSurface.withValues(alpha: 0.3),
                      fontSize: context.rsp(14),
                    ),
                    filled: true,
                    fillColor: colors.surfaceSoft,
                    contentPadding: EdgeInsets.symmetric(
                      vertical: context.rh(12),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colors.border),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: results.isEmpty
                ? Padding(
                    padding: EdgeInsets.all(context.rr(28)),
                    child: Text(
                      'No depot matches that.',
                      style: TextStyle(
                        fontSize: context.rsp(13),
                        color: colors.textSecondary,
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.fromLTRB(
                      context.rw(16),
                      0,
                      context.rw(16),
                      context.rh(24),
                    ),
                    itemCount: results.length,
                    separatorBuilder: (_, __) =>
                        SizedBox(height: context.rh(8)),
                    itemBuilder: (context, index) {
                      final depot = results[index];
                      return InkWell(
                        onTap: () => Navigator.of(context).pop(depot),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: EdgeInsets.all(context.rr(12)),
                          decoration: BoxDecoration(
                            color: colors.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: colors.border),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      depot.code,
                                      style: TextStyle(
                                        fontSize: context.rsp(11),
                                        fontWeight: FontWeight.w700,
                                        color: scheme.primary,
                                      ),
                                    ),
                                    SizedBox(height: context.rh(2)),
                                    Text(
                                      depot.name,
                                      style: TextStyle(
                                        fontSize: context.rsp(14),
                                        fontWeight: FontWeight.w700,
                                        color: colors.textPrimary,
                                      ),
                                    ),
                                    SizedBox(height: context.rh(2)),
                                    Text(
                                      depot.territory,
                                      style: TextStyle(
                                        fontSize: context.rsp(11.5),
                                        color: colors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: context.rr(20),
                                color: colors.textSecondary,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
