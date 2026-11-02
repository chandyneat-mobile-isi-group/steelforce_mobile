import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/features/my_visits/presentation/widgets/sync/pending_plan_visits_section.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/pending_plan_visits_cubit.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/depots/presentation/bloc/depot_registration_queue_cubit.dart';
import 'package:steelforce/features/depots/presentation/widgets/sync/pending_depot_registrations_section.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/pending_visit_sync_cubit.dart';
import 'package:steelforce/features/my_visits/presentation/widgets/sync/pending_visits_section.dart';
import 'package:steelforce/features/order/domain/entities/sync_queue_item.dart';
import 'package:steelforce/features/order/presentation/bloc/sync/pending_sync_cubit.dart';
import 'package:steelforce/features/order/presentation/bloc/sync/pending_sync_state.dart';
import 'package:steelforce/features/shell/presentation/widgets/sync/pending_sync/pending_sync_empty_queue.dart';
import 'package:steelforce/features/shell/presentation/widgets/sync/pending_sync/pending_sync_filter_tiles.dart';
import 'package:steelforce/features/shell/presentation/widgets/sync/pending_sync/pending_sync_header.dart';
import 'package:steelforce/features/shell/presentation/widgets/sync/pending_sync/quotation_queue_tile.dart';
import 'package:steelforce/shared/widgets/brand_wallpaper_background.dart';

/// The Sync Center sheet's body: wallpaper, header, filter tiles, and the
/// filtered list of pending depots, visits and quotations (or the empty
/// state). Opened by `showPendingSyncSheet`.
class PendingSyncCenterView extends StatefulWidget {
  const PendingSyncCenterView({super.key});

  @override
  State<PendingSyncCenterView> createState() => _PendingSyncCenterViewState();
}

class _PendingSyncCenterViewState extends State<PendingSyncCenterView> {
  PendingSyncFilter _filter = PendingSyncFilter.all;

  bool _shows(PendingSyncFilter kind) =>
      _filter == PendingSyncFilter.all || _filter == kind;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        // The brand pattern fills behind; the content sets the sheet height.
        child: Stack(
          children: [
            const Positioned.fill(
              // Subtle, not vivid: this sheet's text sits on it directly,
              // and grey or dark text is unreadable on the vivid blue.
              child:
                  BrandWallpaperBackground(style: BrandWallpaperStyle.subtle),
            ),
            BlocBuilder<PendingSyncCubit, PendingSyncState>(
              builder: (context, state) {
                final depots =
                    context.watch<DepotRegistrationQueueCubit>().state;
                final visitState = context.watch<PendingVisitSyncCubit>().state;
                final visits = visitState.pending;
                final plans =
                    context.watch<PendingPlanVisitsCubit>().state.visits;
                final scheme = Theme.of(context).colorScheme;
                final colors = context.appColors;
                final counts = {
                  PendingSyncFilter.depots: depots.items.length,
                  PendingSyncFilter.visits: visits.stops.length +
                      (visits.otherRecords > 0 ? 1 : 0) +
                      plans.length,
                  PendingSyncFilter.quotations: state.items.length,
                };
                final total = counts.values.fold(0, (a, b) => a + b);
                final quotations = _shows(PendingSyncFilter.quotations)
                    ? state.items
                    : const <SyncQueueItem>[];
                final empty = (!_shows(PendingSyncFilter.depots) ||
                        depots.items.isEmpty) &&
                    (!_shows(PendingSyncFilter.visits) ||
                        (visits.isEmpty && plans.isEmpty)) &&
                    quotations.isEmpty;

                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PendingSyncHeader(
                        total: total,
                        showSyncNow: state.counts.pending > 0 ||
                            depots.sending > 0 ||
                            !visits.isEmpty ||
                            plans.isNotEmpty,
                        isSyncing: state.isSyncing ||
                            depots.syncing ||
                            visitState.syncing,
                      ),
                      SizedBox(height: context.rh(12)),
                      PendingSyncFilterTiles(
                        selected: _filter,
                        total: total,
                        counts: counts,
                        onSelect: (f) => setState(() => _filter = f),
                      ),
                      SizedBox(height: context.rh(8)),
                      Text(
                        'sync.auto_sync_hint'.tr,
                        style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: context.rsp(11.5)),
                      ),
                      SizedBox(height: context.rh(10)),
                      if (empty)
                        const PendingSyncEmptyQueue()
                      else
                        Flexible(
                          child: ListView(
                            shrinkWrap: true,
                            children: [
                              if (_shows(PendingSyncFilter.depots))
                                const PendingDepotRegistrationsSection(),
                              if (_shows(PendingSyncFilter.visits)) ...[
                                const PendingPlanVisitsSection(),
                                const PendingVisitsSection(),
                              ],
                              if (quotations.isNotEmpty) ...[
                                Text(
                                  'sync_center.quotation.section_title'.tr,
                                  style: TextStyle(
                                    fontSize: context.rsp(13),
                                    fontWeight: FontWeight.w800,
                                    color: scheme.onSurface,
                                  ),
                                ),
                                SizedBox(height: context.rh(8)),
                                for (final (i, item) in quotations.indexed) ...[
                                  if (i > 0) SizedBox(height: context.rh(10)),
                                  QuotationQueueTile(item: item),
                                ],
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
