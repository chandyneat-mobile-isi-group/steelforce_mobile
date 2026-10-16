import 'dart:async';
import 'package:steelforce/core/config/feature_flags.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/network/api/api_defaults.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/localization/localized_text_context.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_note.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_photo.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_status.dart';
import 'package:steelforce/features/my_visits/domain/usecases/add_visit_note.dart';
import 'package:steelforce/features/my_visits/domain/usecases/add_visit_photo.dart';
import 'package:steelforce/features/my_visits/domain/repositories/ad_hoc_visit_repository.dart';
import 'package:steelforce/features/my_visits/domain/usecases/routes_params.dart';
import 'package:steelforce/features/my_visits/domain/usecases/update_stop_status.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/ad_hoc_visit_cubit.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/route_sync_cubit.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/stop_dashboard_cubit.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/state/ad_hoc_visit_state.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/state/route_sync_state.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/state/stop_dashboard_state.dart';
import 'package:steelforce/features/my_visits/presentation/models/today_stop.dart';
import 'package:steelforce/features/my_visits/presentation/navigation/open_quotation.dart';
import 'package:steelforce/features/my_visits/presentation/navigation/open_stop_information.dart';
import 'package:steelforce/features/my_visits/presentation/screens/stops_map_screen.dart';
import 'package:steelforce/features/my_visits/presentation/widgets/calendar/calendar_widget_section.dart';
import 'package:steelforce/features/my_visits/presentation/widgets/pending_ad_hoc_card.dart';
import 'package:steelforce/features/my_visits/presentation/widgets/stop_card.dart';
import 'package:steelforce/features/my_visits/presentation/widgets/stop_card_skeleton.dart';
import 'package:steelforce/features/my_visits/presentation/widgets/today_visits_progress_cart.dart';
import 'package:steelforce/features/my_visits/presentation/navigation/add_depot_to_today.dart';
import 'package:steelforce/core/animations/fade_slide_transition.dart';
import 'package:steelforce/core/animations/page_transition.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/features/shell/presentation/bloc/home_cubit.dart';

/// The primary My Visits entry point: today's stops, sorted nearest-first by
/// live location. Replaces the route-centric dashboard.
///
/// Reps see *stops* directly (not routes); the list re-sorts as they move.
/// Offline-first — data is the local Drift stream; distance/sort/search are all
/// local. Kicks route sync on open; the live stream picks up whatever lands.
class StopDashboardScreen extends StatefulWidget {
  const StopDashboardScreen({super.key});

  @override
  State<StopDashboardScreen> createState() => _StopDashboardScreenState();
}

class _StopDashboardScreenState extends State<StopDashboardScreen> {
  final ShellTabController _tabs = sl<ShellTabController>();

  @override
  void initState() {
    super.initState();
    // The only source of routes: pull from the backend, push what's pending.
    // Debug fixture seeding used to run here too, writing hardcoded routes
    // straight into the live database on every launch. It has been removed —
    // seeded rows are indistinguishable from synced ones once written, so they
    // sat on top of real API data and made an empty or wrong route feed look
    // populated. Mock data now has exactly one entry point:
    // `--dart-define=USE_MOCK_DATA=true`, which swaps the *remote* source and
    // leaves the database honest about where its rows came from.
    unawaited(_openOnlineFirst());
    _tabs.addListener(_onTabChanged);
    // Ad hoc requests that never reached the server get another go on every
    // open. Safe to drain twice: the stored `clientRequestId` makes the server
    // return the original visit rather than creating a second one.
    final adHoc = context.read<AdHocVisitCubit>()..start();
    unawaited(_drainAdHoc(adHoc));
  }

  /// Online-first open: pull from the API, then render.
  ///
  /// The dashboard stays on its skeleton while the pull runs, capped at
  /// [ApiDefaults.onlineFirstWait] so a slow connection cannot strand the rep.
  /// Offline, the pull fails fast and the local copy renders at once. A pull
  /// that outlives the cap still lands through the sync listener's reload.
  ///
  /// Pending visit data is pushed *after* the pull rather than alongside it:
  /// both report through [RouteSyncCubit]'s one state, and running them
  /// together interleaved their progress and failure states.
  Future<void> _openOnlineFirst() async {
    final sync = context.read<RouteSyncCubit>();
    final dashboard = context.read<StopDashboardCubit>();
    await sync
        .syncIfNeeded()
        .timeout(ApiDefaults.onlineFirstWait, onTimeout: () {});
    if (!mounted) return;
    unawaited(dashboard.start());
    unawaited(sync.pushPending());
  }

  /// The shell keeps this tab alive in an `IndexedStack`, so `initState` runs
  /// once. Coming back to My Visits pulls again; the sync listener reloads the
  /// list when the pull lands.
  void _onTabChanged() {
    if (_tabs.value == ShellTab.myVisits && mounted) {
      context.read<RouteSyncCubit>().syncIfNeeded();
    }
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChanged);
    super.dispose();
  }

  /// Drains the ad hoc queue and refreshes the routes only if something
  /// actually landed — a refresh per open would cost a round trip for nothing.
  Future<void> _drainAdHoc(AdHocVisitCubit adHoc) async {
    final delivered = await adHoc.drainQueue();
    if (!mounted || !delivered) return;
    await context.read<RouteSyncCubit>().refresh();
    if (mounted) context.read<StopDashboardCubit>().reload();
  }

  Future<void> _refresh(BuildContext context) async {
    final sync = context.read<RouteSyncCubit>();
    // Before the pull, not after: a queued ad hoc visit that lands now is
    // included in the very refresh the rep is waiting on, instead of appearing
    // one pull later.
    await context.read<AdHocVisitCubit>().drainQueue();
    await sync.refresh();
    await sync.pushPending();
  }

  /// Opens the full-screen map of the day the rep is looking at.
  ///
  /// Handed the stops the list is already showing rather than re-querying, so
  /// the map and the list cannot disagree about the day.
  void _openMap(BuildContext context, StopDashboardLoaded state) {
    Navigator.of(context).push(
      AppPageRoute<void>.sharedAxisVertical(
        builder: (_) => StopsMapScreen(
          stops: state.visibleStops,
          selectedDate: state.selectedDate,
        ),
      ),
    );
  }

  /// Acts on the cubit's one-shot outcome, then clears it so a rebuild cannot
  /// replay it.
  Future<void> _onAdHocEffect(
      BuildContext context, AdHocVisitEffect effect) async {
    final messenger = ScaffoldMessenger.of(context);
    final adHoc = context.read<AdHocVisitCubit>();
    adHoc.clearEffect();

    switch (effect) {
      case AdHocVisitCreated(:final depotName):
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
              content: Text(
                  'my_visits.ad_hoc.added'.trParams({'name': depotName}))));
        // The stop and its depot are already written locally, so the card can
        // appear now; the refresh fills in the route header for a day the
        // server opened for this rep.
        await context.read<RouteSyncCubit>().refresh();
        if (context.mounted) context.read<StopDashboardCubit>().reload();

      case AdHocVisitAlreadyThere(:final depotName):
        // Not an error. The depot is on their day either way — say so plainly
        // and reload, which surfaces the card they already have.
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
              content: Text('my_visits.ad_hoc.already_there'
                  .trParams({'name': depotName}))));
        context.read<StopDashboardCubit>().reload();

      case AdHocVisitWaiting(:final depotName):
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
              content: Text(
                  'my_visits.ad_hoc.queued'.trParams({'name': depotName}))));

      case AdHocVisitRefused(:final message, :final supportReference):
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text(adHocRefusalText(message, supportReference),
                maxLines: 4, overflow: TextOverflow.ellipsis),
            backgroundColor: Theme.of(context).colorScheme.error,
          ));
    }
  }

  /// The basket action on a stop card: quote this shop.
  ///
  /// Goes straight to the Quotation Builder with the outlet already chosen,
  /// through the same `openQuotationForDepot` the guided visit flow and
  /// "Continue Working" use — so a quotation raised from the dashboard is
  /// built, priced and filed identically to one raised mid-visit.
  ///
  /// Not gated here. `StopCard` already decides when the basket is offered at
  /// all — it is hidden while the stop is still `pending` — so re-checking the
  /// status on the way out would only add a second, silently disagreeing rule.
  void _openQuotation(BuildContext context, TodayStop todayStop) {
    final depot = todayStop.stop.depot;
    unawaited(openQuotationForDepot(
      context,
      depotId: depot.id,
      depotName: context.localized(depot.displayName),
    ));
  }

  void _openStop(
      BuildContext context, TodayStop todayStop, List<TodayStop> visibleStops) {
    final index =
        visibleStops.indexWhere((s) => s.stop.id == todayStop.stop.id);
    openStopInformation(
      context,
      stop: todayStop.stop,
      index: index != -1 ? index : 0,
      totalStops: visibleStops.length,
    );
  }

  /// Marks a stop missed with the rep's reason (always) and proof photo (if
  /// taken), then reloads so the card reflects it immediately — the dashboard
  /// has no live `ActiveRouteBloc` for an arbitrary stop from this flattened
  /// list, so this writes straight through the usecases, the same way
  /// `CompleteVisitCheckOut` is triggered from contexts with no bloc.
  Future<void> _skipStop(
    BuildContext context,
    TodayStop todayStop,
    String reason,
    String? photoPath,
  ) async {
    final stopId = todayStop.stop.id;
    final now = DateTime.now();

    await sl<UpdateStopStatus>()(
        UpdateStopStatusParams(stopId: stopId, status: VisitStatus.missed));
    await sl<AddVisitNote>()(VisitNote(
      id: '${now.microsecondsSinceEpoch}',
      stopId: stopId,
      type: VisitNoteType.general,
      text: 'Visit skipped: $reason',
      createdAt: now,
    ));
    if (photoPath != null) {
      await sl<AddVisitPhoto>()(VisitPhoto(
        id: '${now.microsecondsSinceEpoch}-photo',
        stopId: stopId,
        url: photoPath,
        caption: 'Skip proof: $reason',
        takenAt: now,
      ));
    }

    if (context.mounted) {
      context.read<StopDashboardCubit>().reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.canvas,
      body: SafeArea(
        child: BlocListener<RouteSyncCubit, RouteSyncState>(
          listenWhen: (p, c) => c is RouteSyncFailed || c is RouteSyncSucceeded,
          listener: (context, state) {
            // A pull that lands after the cubit took its opening snapshot is
            // otherwise invisible to it — sync writes through the local data
            // source, not the repository whose stream this screen watches. See
            // `StopDashboardCubit.reload`.
            if (state is RouteSyncSucceeded) {
              context.read<StopDashboardCubit>().reload();
              return;
            }
            if (state is RouteSyncFailed) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(
                  content: Text(state.message,
                      maxLines: 3, overflow: TextOverflow.ellipsis),
                  action: SnackBarAction(
                    label: 'common.retry'.tr,
                    onPressed: () =>
                        context.read<RouteSyncCubit>().syncIfNeeded(),
                  ),
                ));
            }
          },
          // Nested rather than merged into the sync listener above: the two
          // watch different cubits and fire on different conditions.
          child: BlocListener<AdHocVisitCubit, AdHocVisitState>(
            listenWhen: (p, c) => c.effect != null && p.effect != c.effect,
            listener: (context, state) {
              final effect = state.effect;
              if (effect != null) unawaited(_onAdHocEffect(context, effect));
            },
            child: BlocBuilder<StopDashboardCubit, StopDashboardState>(
              builder: (context, state) => switch (state) {
                StopDashboardError(:final message) => Center(
                    child: Text(message,
                        style: TextStyle(color: colors.textSecondary))),
                StopDashboardLoaded() => _LoadedView(
                    state: state,
                    onRefresh: () => _refresh(context),
                    onTapStop: (s) => _openStop(context, s, state.visibleStops),
                    onQuotationStop: (s) => _openQuotation(context, s),
                    onSkipStop: (s, reason, photoPath) =>
                        _skipStop(context, s, reason, photoPath),
                    onFilter: (f) =>
                        context.read<StopDashboardCubit>().setFilter(f),
                    onQuery: (q) =>
                        context.read<StopDashboardCubit>().setQuery(q),
                    onOpenMap: () => _openMap(context, state),
                  ),
                _ => const StopDashboardSkeleton(),
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadedView extends StatefulWidget {
  const _LoadedView({
    required this.state,
    required this.onRefresh,
    required this.onTapStop,
    required this.onQuotationStop,
    required this.onSkipStop,
    required this.onFilter,
    required this.onQuery,
    required this.onOpenMap,
  });

  final StopDashboardLoaded state;
  final Future<void> Function() onRefresh;
  final void Function(TodayStop stop) onTapStop;
  final void Function(TodayStop stop) onQuotationStop;
  final void Function(TodayStop stop, String reason, String? photoPath)
      onSkipStop;
  final void Function(StopFilter filter) onFilter;
  final void Function(String query) onQuery;
  final VoidCallback onOpenMap;

  @override
  State<_LoadedView> createState() => _LoadedViewState();
}

class _LoadedViewState extends State<_LoadedView> {
  DateTime _focusedMonth = DateTime.now();

  int _getStopCountForDate(DateTime date) => widget.state.stopCountForDay(date);

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final visible = widget.state.visibleStops;

    // Check if the currently selected date is TODAY
    final isSelectedToday = DateUtils.isSameDay(
      widget.state.selectedDate,
      DateTime.now(),
    );

    // Count metrics for progress bar
    final total = widget.state.stops.length;
    final visited = widget.state.stops
        .where((s) => s.stop.status == VisitStatus.checkedOut)
        .length;
    final skipped = widget.state.stops
        .where((s) => s.stop.status == VisitStatus.missed)
        .length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      // No "Add visit" button here: a visit is added from the depot — the
      // HC Visit action on its card or in Depot Details.
      body: RefreshIndicator(
        color: scheme.primary,
        backgroundColor: colors.surfaceSoft,
        onRefresh: widget.onRefresh,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                    context.rw(20), context.rh(12), context.rw(20), 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StopCalendarSection(
                      focusedMonth: _focusedMonth,
                      selectedDate: widget.state.selectedDate,
                      onMonthChanged: (newMonth) =>
                          setState(() => _focusedMonth = newMonth),
                      onDateSelected: (newDate) => context
                          .read<StopDashboardCubit>()
                          .setSelectedDate(newDate),
                      stopCountForDate: _getStopCountForDate,
                      // Hidden while the day has nothing to plot: a map button
                      // that opens an empty map is a dead end, not a feature.
                      onOpenMap: visible.isEmpty ? null : widget.onOpenMap,
                    ),
                    SizedBox(height: context.rh(14)),
                    TodayVisitProgressCard(
                      totalVisits: total,
                      visitedCount: visited,
                      skippedCount: skipped,
                    ),
                    SizedBox(height: context.rh(12)),
                  ],
                ),
              ),
            ),
            // Requests still in flight, above the list and only for today —
            // they are being added to today by definition, so showing them
            // while the rep browses last Tuesday would be a lie.
            if (isSelectedToday)
              SliverToBoxAdapter(
                child: BlocSelector<AdHocVisitCubit, AdHocVisitState,
                    List<PendingAdHocVisit>>(
                  selector: (state) => state.pending,
                  builder: (context, pending) => pending.isEmpty
                      ? const SizedBox.shrink()
                      : Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: context.rw(20)),
                          child: Column(
                            children: [
                              for (final request in pending)
                                PendingAdHocCard(
                                    key: ValueKey(request.clientRequestId),
                                    request: request),
                            ],
                          ),
                        ),
                ),
              ),
            if (visible.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(hasAnyStops: widget.state.stops.isNotEmpty),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(context.rw(20), context.rh(4),
                    context.rw(20), context.rh(24)),
                sliver: SliverList.builder(
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final todayStop = visible[index];
                    return FadeSlideIn(
                      // Keyed by stop, so a card that survives a filter or a
                      // status change is not torn down and re-entered. Without
                      // this the whole list replays its entrance every time the
                      // rep types in the search box.
                      key: ValueKey(todayStop.stop.id),
                      // FS-ANI-6: the stagger stops after the sixth card. A
                      // route can hold twenty stops, and twenty cascading
                      // entrances reads as a slow app, not a considered one —
                      // everything past the visible handful arrives together.
                      delay: FadeSlideIn.staggerDelay(
                          index < _kStaggerLimit ? index : _kStaggerLimit),
                      child: StopCard(
                        todayStop: todayStop,
                        isToday: isSelectedToday,
                        onTap: () => widget.onTapStop(todayStop),
                        onQuotationTap: FeatureFlags.quotesAndOrders
                            ? () => widget.onQuotationStop(todayStop)
                            : null,
                        onSkipSubmitted: (reason, photoPath) =>
                            widget.onSkipStop(todayStop, reason, photoPath),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// How many stop cards stagger before the rest arrive together (FS-ANI-6).
const int _kStaggerLimit = 6;

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasAnyStops});
  final bool hasAnyStops;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(context.rw(32)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasAnyStops
                  ? Icons.filter_alt_off_rounded
                  : Icons.event_available_rounded,
              size: context.rw(40),
              color: colors.textHint,
            ),
            SizedBox(height: context.rh(12)),
            Text(
              hasAnyStops
                  ? 'my_visits.stop_dashboard.no_matches'.tr
                  : 'my_visits.stop_dashboard.no_stops_today'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: context.rsp(14),
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: context.rh(6)),
            Text(
              hasAnyStops
                  ? 'my_visits.stop_dashboard.no_matches_hint'.tr
                  : 'my_visits.stop_dashboard.pull_to_sync'.tr,
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
