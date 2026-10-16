import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/localization/localized_builder.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/depots/domain/entities/depot.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/depot_selection_cubit.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/state/depot_selection_state.dart';
import 'package:steelforce/features/my_visits/presentation/navigation/add_depot_to_today.dart';

/// The depot a rep picked to add to today, or null if they backed out.
class AdHocDepotChoice {
  const AdHocDepotChoice({
    required this.depotId,
    required this.sk,
    required this.depotName,
  });
  final String depotId;

  /// The SAP code the endpoint is keyed on. Always present: a depot without
  /// one cannot be picked.
  final String sk;
  final String depotName;
}

/// Picks a depot to add to today's visits.
///
/// Reuses [DepotSelectionCubit] — shops *are* depots, and the Depot Stock flow
/// already browses them offline-first from the local directory. No new data
/// layer, and no dependency on the depots feature's `data/` (CLAUDE.md §4):
/// that cubit reaches its own domain usecase.
///
/// [excludedDepotIds] are the depots already on the day. They are hidden rather
/// than shown-and-disabled: a disabled row invites a tap that can only ever
/// answer "already on today's route", which is a round trip to learn nothing.
///
/// Depots SAP has not reported back yet are the opposite case: they are shown
/// **disabled**, with the reason, because the rep may well be searching for
/// exactly that shop and a silent absence reads as "the app lost it".
Future<AdHocDepotChoice?> showAddAdHocVisitSheet(
  BuildContext context, {
  required Set<String> excludedDepotIds,
}) {
  return showModalBottomSheet<AdHocDepotChoice>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    // The sheet holds a search field; without this the keyboard covers it.
    builder: (_) => Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: BlocProvider(
        create: (_) => sl<DepotSelectionCubit>()..load(),
        child: LocalizedBuilder(
          builder: (_) =>
              _AddAdHocVisitSheet(excludedDepotIds: excludedDepotIds),
        ),
      ),
    ),
  );
}

class _AddAdHocVisitSheet extends StatelessWidget {
  const _AddAdHocVisitSheet({required this.excludedDepotIds});

  final Set<String> excludedDepotIds;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(context.rr(20))),
        ),
        child: Column(
          children: [
            SizedBox(height: context.rh(10)),
            Container(
              width: context.rw(40),
              height: context.rh(4),
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(context.rr(2)),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(context.rw(20), context.rh(14),
                  context.rw(20), context.rh(8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'my_visits.ad_hoc.sheet_title'.tr,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: context.rsp(16),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: context.rh(4)),
                  Text(
                    'my_visits.ad_hoc.sheet_subtitle'.tr,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: context.rsp(12),
                    ),
                  ),
                  SizedBox(height: context.rh(12)),
                  _SearchField(
                    onChanged: (q) =>
                        context.read<DepotSelectionCubit>().search(q),
                  ),
                ],
              ),
            ),
            Expanded(
              child: BlocBuilder<DepotSelectionCubit, DepotSelectionState>(
                builder: (context, state) => switch (state.status) {
                  DepotSelectionStatus.loading ||
                  DepotSelectionStatus.initial =>
                    const Center(child: CircularProgressIndicator()),
                  DepotSelectionStatus.error => _SheetMessage(
                      icon: Icons.error_outline_rounded,
                      title: 'my_visits.ad_hoc.load_failed'.tr,
                      // The failure's own message, which the repository has
                      // already made user-safe.
                      body: state.message ?? 'common.generic_error'.tr,
                    ),
                  DepotSelectionStatus.empty => _SheetMessage(
                      icon: Icons.storefront_outlined,
                      title: 'my_visits.ad_hoc.none_found'.tr,
                      body: 'my_visits.ad_hoc.none_found_hint'.tr,
                    ),
                  DepotSelectionStatus.loaded => _DepotList(
                      // Filtered here rather than in the cubit: the exclusion
                      // is this screen's concern, and pushing it down would
                      // make the shared Depot Stock flow hide shops too.
                      depots: [
                        for (final d in state.shops)
                          if (!excludedDepotIds.contains(d.id)) d,
                      ],
                      allHidden: state.shops.isNotEmpty &&
                          state.shops
                              .every((d) => excludedDepotIds.contains(d.id)),
                      scrollController: scrollController,
                    ),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.onChanged});
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return TextField(
      onChanged: onChanged,
      style: TextStyle(color: colors.textPrimary, fontSize: context.rsp(13.5)),
      decoration: InputDecoration(
        hintText: 'my_visits.ad_hoc.search_hint'.tr,
        hintStyle: TextStyle(color: colors.textHint, fontSize: context.rsp(13)),
        prefixIcon: Icon(Icons.search_rounded,
            color: colors.iconMuted, size: context.rr(20)),
        filled: true,
        fillColor: colors.surfaceSoft,
        contentPadding: EdgeInsets.symmetric(vertical: context.rh(12)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(context.rr(12)),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(context.rr(12)),
          borderSide: BorderSide(color: colors.border),
        ),
      ),
    );
  }
}

class _DepotList extends StatelessWidget {
  const _DepotList({
    required this.depots,
    required this.allHidden,
    required this.scrollController,
  });

  final List<Depot> depots;

  /// True when the directory had rows but every one is already on the day —
  /// a different situation from "no shops match", and a rep should not be left
  /// wondering whether search is broken.
  final bool allHidden;

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    if (depots.isEmpty) {
      return _SheetMessage(
        icon: allHidden
            ? Icons.event_available_rounded
            : Icons.search_off_rounded,
        title: allHidden
            ? 'my_visits.ad_hoc.all_on_route'.tr
            : 'my_visits.ad_hoc.none_found'.tr,
        body: allHidden
            ? 'my_visits.ad_hoc.all_on_route_hint'.tr
            : 'my_visits.ad_hoc.none_found_hint'.tr,
      );
    }

    final colors = context.appColors;
    return ListView.separated(
      controller: scrollController,
      padding: EdgeInsets.fromLTRB(
          context.rw(20), 0, context.rw(20), context.rh(24)),
      itemCount: depots.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: colors.border),
      itemBuilder: (context, index) {
        final depot = depots[index];
        final sk = depot.adHocVisitCode;
        return ListTile(
          enabled: sk != null,
          contentPadding: EdgeInsets.symmetric(vertical: context.rh(4)),
          leading: Container(
            width: context.rr(38),
            height: context.rr(38),
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(context.rr(10)),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.storefront_rounded,
                size: context.rr(18),
                color: Theme.of(context).colorScheme.primary),
          ),
          title: Text(
            depot.shopName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: context.rsp(13.5),
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Text(
            sk == null
                ? 'my_visits.ad_hoc.not_in_sap'.tr
                : depot.address.isEmpty
                    ? depot.depotCode
                    : depot.address,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: colors.textSecondary, fontSize: context.rsp(11.5)),
          ),
          trailing: Icon(
              sk == null
                  ? Icons.block_rounded
                  : Icons.add_circle_outline_rounded,
              size: context.rr(20),
              color: sk == null
                  ? colors.textHint
                  : Theme.of(context).colorScheme.primary),
          onTap: sk == null
              ? null
              : () => Navigator.of(context).pop(
                    AdHocDepotChoice(
                      depotId: depot.id,
                      sk: sk,
                      depotName: depot.shopName,
                    ),
                  ),
        );
      },
    );
  }
}

class _SheetMessage extends StatelessWidget {
  const _SheetMessage({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(context.rw(32)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: context.rw(38), color: colors.textHint),
            SizedBox(height: context.rh(12)),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: context.rsp(14),
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: context.rh(6)),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: colors.textSecondary, fontSize: context.rsp(12)),
            ),
          ],
        ),
      ),
    );
  }
}
