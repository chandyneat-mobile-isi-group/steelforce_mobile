import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/features/depots/domain/entities/depot_filter.dart';
import 'package:steelforce/features/depots/presentation/widgets/depot_advanced_filter_panel.dart';
import 'package:steelforce/features/depots/presentation/widgets/depot_advanced_filter_button.dart';
import 'package:steelforce/features/my_visits/presentation/navigation/add_depot_to_today.dart';
import 'package:steelforce/features/my_visits/presentation/navigation/today_visit_rules.dart';
import 'package:steelforce/features/app_coach/domain/entities/coach_module.dart';
import 'package:steelforce/core/practice/practice_session.dart';
import 'package:steelforce/core/localization/localized_text_context.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/network/api/api_defaults.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/localization/localized_builder.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/app_coach/presentation/services/coach_keys.dart';
import 'package:steelforce/features/depots/data/models/depot_registration_type.dart';
import 'package:steelforce/features/depots/domain/entities/depot.dart';
import 'package:steelforce/features/depots/domain/entities/depot_list_kind.dart';
import 'package:steelforce/features/depots/presentation/bloc/depot_code_lookup_cubit.dart';
import 'package:steelforce/features/depots/presentation/bloc/depot_sync_cubit.dart';
import 'package:steelforce/features/depots/presentation/bloc/depot_sync_state.dart';
import 'package:steelforce/features/depots/presentation/bloc/depots_bloc.dart';
import 'package:steelforce/features/depots/presentation/bloc/depots_event.dart';
import 'package:steelforce/features/depots/presentation/bloc/depots_state.dart';
import 'package:steelforce/features/depots/presentation/screens/depot_detail_screen.dart';
import 'package:steelforce/features/depots/presentation/screens/depot_create_screen.dart';
import 'package:steelforce/features/depots/presentation/widgets/depot_audience_filter.dart';
import 'package:steelforce/features/depots/presentation/widgets/depot_card.dart';
import 'package:steelforce/features/depots/presentation/widgets/depot_empty_state.dart';
import 'package:steelforce/features/depots/presentation/widgets/depot_error_state.dart';
import 'package:steelforce/features/depots/presentation/widgets/depot_loading.dart';
import 'package:steelforce/features/depots/presentation/widgets/depot_search_bar.dart';
import 'package:steelforce/features/depots/presentation/widgets/depot_sync_status_banner.dart';
import 'package:steelforce/features/shell/presentation/navigation/shell_tab_controller.dart';
import 'package:steelforce/features/my_visits/presentation/navigation/open_quotation.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/shared/widgets/brand_wallpaper_background.dart';

enum _QuickAccess {
  all,
  depot,
  salesOrg,
  division,
  recent,
  favorites;

  bool get isGrouped =>
      this == _QuickAccess.depot ||
      this == _QuickAccess.salesOrg ||
      this == _QuickAccess.division;

  String get label => switch (this) {
        _QuickAccess.all => 'depots.all'.tr,
        _QuickAccess.depot => 'depots.group.depot'.tr,
        _QuickAccess.salesOrg => 'depots.group.sales_org'.tr,
        _QuickAccess.division => 'depots.group.division'.tr,
        _QuickAccess.recent => 'depots.recent'.tr,
        _QuickAccess.favorites => 'depots.favorites'.tr,
      };
}

sealed class _Row {
  const _Row();
}

class _HeaderRow extends _Row {
  const _HeaderRow(this.title, this.count);
  final String title;
  final int count;
}

class _DepotRow extends _Row {
  const _DepotRow(this.depot);
  final Depot depot;
}

class DepotsScreen extends StatelessWidget {
  const DepotsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        // Neither starts itself: `_DepotsView` pulls from the API first and
        // only then loads the list, so an online rep sees today's directory.
        BlocProvider(create: (_) => sl<DepotsBloc>()),
        BlocProvider(create: (_) => sl<DepotSyncCubit>()),
        BlocProvider(create: (_) => sl<DepotCodeLookupCubit>()),
      ],
      child: const _DepotsView(),
    );
  }
}

class _DepotsView extends StatefulWidget {
  const _DepotsView();

  @override
  State<_DepotsView> createState() => _DepotsViewState();
}

class _DepotsViewState extends State<_DepotsView> {
  final _scrollController = ScrollController();
  _QuickAccess _quickAccess = _QuickAccess.all;

  final ShellTabController _tabs = sl<ShellTabController>();

  /// Outlets that already had their ad hoc visit today; their action shows
  /// grey.
  Set<String> _adHocToday = const {};

  /// The Advanced Filters panel is open.
  bool _filtersOpen = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _tabs.addListener(_onTabChanged);
    _loadOnlineFirst();
    _loadAdHocToday();
  }

  Future<void> _loadAdHocToday() async {
    final outlets = await adHocOutletsToday();
    if (mounted) setState(() => _adHocToday = outlets);
  }

  /// Online-first open: pull from the API, then render.
  ///
  /// The list holds its loading state while the pull runs, capped at
  /// [ApiDefaults.onlineFirstWait] so a slow connection cannot strand the rep
  /// on a skeleton. Offline, the pull fails fast and the local copy renders at
  /// once. A pull that outlives the cap still lands: [_onSyncChanged] reloads
  /// the list when it succeeds.
  Future<void> _loadOnlineFirst() async {
    await context
        .read<DepotSyncCubit>()
        .syncIfNeeded()
        .timeout(ApiDefaults.onlineFirstWait, onTimeout: () {});
    if (mounted) context.read<DepotsBloc>().add(const DepotsLoadRequested());
  }

  /// The shell keeps this tab alive in an `IndexedStack`, so `initState` runs
  /// once. Coming back to the tab is the rep asking for the directory again —
  /// pull again; the list refreshes itself when the pull lands.
  void _onTabChanged() {
    if (_tabs.value == ShellTab.depots && mounted) {
      context.read<DepotSyncCubit>().syncIfNeeded();
      _loadAdHocToday();
    }
  }

  /// Reloads the list whenever a pull brings rows in, however it was started.
  /// Before the first load the pending [_loadOnlineFirst] covers it.
  void _onSyncChanged(BuildContext context, DepotSyncState sync) {
    if (sync is! DepotSyncSucceeded) return;
    _loadAdHocToday();
    final bloc = context.read<DepotsBloc>();
    if (bloc.state is DepotsLoaded) bloc.add(const DepotsRefreshRequested());
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      context.read<DepotsBloc>().add(const DepotsLoadMoreRequested());
    }
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _openDetail(BuildContext context, String depotId) {
    Navigator.of(context).push(MaterialPageRoute(
      settings: const RouteSettings(name: DepotDetailScreen.routeName),
      builder: (_) => DepotDetailScreen(depotId: depotId),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return LocalizedBuilder(
      builder: (context) => Scaffold(
        // The shell's canvas, so every tab sits on the same ground as Home.
        backgroundColor: Colors.transparent,
        floatingActionButton: CoachKeys.wrap(
          CoachKeys.depotAdd,
          child: FloatingActionButton.extended(
            heroTag: 'depots_register',
            onPressed: () => _registerDepot(context),
            icon: const Icon(Icons.add_rounded),
            label: Text('depots.register_fab'.tr),
          ),
        ),
        // The by-code lookup's three outcomes are handled here, and they are
        // deliberately not interchangeable: "absent" invites a registration,
        // "unavailable" must not — offering one when the ERP merely could not
        // be reached creates a duplicate business partner in SAP.
        body: BrandWallpaperBody(
            style: BrandWallpaperStyle.vivid,
            child: MultiBlocListener(
              listeners: [
                BlocListener<DepotCodeLookupCubit, DepotCodeLookupState>(
                  listener: _onLookupResult,
                ),
                BlocListener<DepotSyncCubit, DepotSyncState>(
                  listener: _onSyncChanged,
                ),
              ],
              child: BlocBuilder<DepotsBloc, DepotsState>(
                builder: (context, state) {
                  return switch (state) {
                    // Depots, Non-BP depots and the ones awaiting approval are
                    // one list filtered by kind, so search and paging work
                    // the same on all three.
                    DepotsLoaded() => _Loaded(
                        state: state,
                        adHocToday: _adHocToday,
                        onAdHocAdded: _loadAdHocToday,
                        filtersOpen: _filtersOpen,
                        onToggleFilters: () =>
                            setState(() => _filtersOpen = !_filtersOpen),
                        quickAccess: _quickAccess,
                        onQuickAccessChanged: (q) =>
                            setState(() => _quickAccess = q),
                        audience: DepotAudience.of(state.filter.kind),
                        onAudienceChanged: (a) => context
                            .read<DepotsBloc>()
                            // Another list's regions and types differ: its
                            // filters start clear.
                            .add(DepotsFilterChanged(DepotFilter(
                                kind: a.kind, sortBy: state.filter.sortBy))),
                        scrollController: _scrollController,
                        onOpenDetail: (id) => _openDetail(context, id),
                      ),
                    DepotsError(:final message) => DepotErrorState(
                        message: message,
                        onRetry: () => context
                            .read<DepotsBloc>()
                            .add(const DepotsLoadRequested()),
                      ),
                    _ => const DepotLoading(),
                  };
                },
              ),
            )),
      ),
    );
  }

  void _onLookupResult(BuildContext context, DepotCodeLookupState state) {
    final messenger = ScaffoldMessenger.of(context);

    switch (state) {
      case CodeLookupFound(:final depot):
        // The portal payload carries the platform id, so the ordinary detail
        // screen can open it directly — no second resolution step.
        context.read<DepotCodeLookupCubit>().reset();
        _openDetail(context, depot.id);

      case CodeLookupAbsent():
        // Safe to point the rep at registration: the code exists nowhere.
        messenger.showSnackBar(
          SnackBar(content: Text('depots.lookup_absent'.tr)),
        );

      case CodeLookupUnavailable():
        // Explicitly NOT an invitation to register.
        messenger.showSnackBar(SnackBar(
          backgroundColor: Theme.of(context).colorScheme.error,
          content: Text('depots.lookup_unavailable'.tr),
        ));

      case CodeLookupFailed(:final message):
        messenger.showSnackBar(SnackBar(
          backgroundColor: Theme.of(context).colorScheme.error,
          content: Text(message),
        ));

      case CodeLookupIdle():
      case CodeLookupInProgress():
        break;
    }
  }
}

class _Loaded extends StatelessWidget {
  const _Loaded({
    required this.state,
    required this.quickAccess,
    required this.onQuickAccessChanged,
    required this.audience,
    required this.onAudienceChanged,
    required this.scrollController,
    required this.onOpenDetail,
    required this.adHocToday,
    required this.onAdHocAdded,
    required this.filtersOpen,
    required this.onToggleFilters,
  });

  final DepotsLoaded state;
  final _QuickAccess quickAccess;
  final ValueChanged<_QuickAccess> onQuickAccessChanged;
  final DepotAudience audience;
  final ValueChanged<DepotAudience> onAudienceChanged;
  final ScrollController scrollController;
  final ValueChanged<String> onOpenDetail;
  final Set<String> adHocToday;
  final VoidCallback onAdHocAdded;
  final bool filtersOpen;
  final VoidCallback onToggleFilters;

  List<Depot> get _visibleItems => switch (quickAccess) {
        _QuickAccess.all ||
        _QuickAccess.depot ||
        _QuickAccess.salesOrg ||
        _QuickAccess.division =>
          state.items,
        _QuickAccess.recent => state.recent,
        _QuickAccess.favorites =>
          state.items.where((c) => state.favoriteIds.contains(c.id)).toList(),
      };

  List<_Row> _buildRows(List<Depot> depots) {
    if (!quickAccess.isGrouped) {
      return depots.map<_Row>(_DepotRow.new).toList(growable: false);
    }

    String keyFor(Depot c) => switch (quickAccess) {
          _QuickAccess.depot => c.depotCode.isEmpty
              ? 'depots.unassigned'.tr
              : c.depotCode[0].toUpperCase(),
          _QuickAccess.salesOrg =>
            c.salesOrg?.trim().isNotEmpty == true ? c.salesOrg!.trim() : '—',
          _QuickAccess.division =>
            c.division?.trim().isNotEmpty == true ? c.division!.trim() : '—',
          _ => '',
        };

    final grouped = <String, List<Depot>>{};
    for (final c in depots) {
      grouped.putIfAbsent(keyFor(c), () => <Depot>[]).add(c);
    }

    final keys = grouped.keys.toList()
      ..sort((a, b) {
        if (a == '—') return 1;
        if (b == '—') return -1;
        return a.compareTo(b);
      });

    return [
      for (final key in keys) ...[
        _HeaderRow(
          key == '—' ? 'depots.unassigned'.tr : key,
          grouped[key]!.length,
        ),
        ...grouped[key]!.map<_Row>(_DepotRow.new),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final items = _visibleItems;
    final rows = _buildRows(items);
    // The App Coach points at the first depot on screen, whichever group
    // header precedes it.
    final firstDepotId = rows.whereType<_DepotRow>().firstOrNull?.depot.id;
    final quotationLesson =
        sl<PracticeSession>().lesson == CoachModuleIds.quotation;

    return RefreshIndicator(
      color: scheme.primary,
      backgroundColor: colors.surfaceSoft,
      // The sync listener reloads the list when the pull succeeds; a failed
      // pull changed nothing locally, so there is nothing to reload.
      onRefresh: () => context.read<DepotSyncCubit>().refresh(),
      child: CustomScrollView(
        controller: scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(context.rw(16), context.rh(46),
                  context.rw(16), context.rh(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const DepotSyncStatusBanner(),

                  // Search and its filters first, then which list they act
                  // on — the selected list stays in view just below.
                  DepotSearchBar(
                    query: state.query,
                    onSearchChanged: (q) =>
                        context.read<DepotsBloc>().add(DepotsSearchChanged(q)),
                    trailing: DepotAdvancedFilterButton(
                      open: filtersOpen,
                      activeCount: state.filter.activeCount,
                      onTap: onToggleFilters,
                    ),
                  ),
                  if (filtersOpen) ...[
                    SizedBox(height: context.rh(10)),
                    DepotAdvancedFilterPanel(
                      filter: state.filter,
                      onApply: (f) {
                        context.read<DepotsBloc>().add(DepotsFilterChanged(f));
                        onToggleFilters();
                      },
                    ),
                  ],
                  SizedBox(height: context.rh(12)),
                  DepotAudienceFilter(
                    selected: audience,
                    onChanged: onAudienceChanged,
                  ),
                  SizedBox(height: context.rh(12)),
                ],
              ),
            ),
          ),
          if (items.isEmpty)
            SliverFillRemaining(
              child: BlocBuilder<DepotCodeLookupCubit, DepotCodeLookupState>(
                builder: (context, lookup) {
                  // Offered only when the term is code-shaped. A rep typing a
                  // shop name must not be invited to spend a round trip that
                  // can reach the ERP.
                  final code = looksLikeDepotCode(state.query)
                      ? state.query.trim()
                      : null;
                  return DepotEmptyState(
                    hasActiveSearchOrFilter:
                        state.query.isNotEmpty || !state.filter.isEmpty,
                    onClearSearchOrFilter:
                        state.query.isNotEmpty || !state.filter.isEmpty
                            ? () => _clearSearchAndFilters(context, state)
                            : null,
                    lookupCode: code,
                    onLookupCode: code == null
                        ? null
                        : () =>
                            context.read<DepotCodeLookupCubit>().lookup(code),
                    isLookingUp: lookup is CodeLookupInProgress,
                  );
                },
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                  context.rw(16), 0, context.rw(16), context.rh(16)),
              sliver: SliverList.separated(
                itemCount: rows.length,
                separatorBuilder: (_, __) => SizedBox(height: context.rh(12)),
                itemBuilder: (context, index) {
                  final row = rows[index];
                  return switch (row) {
                    _HeaderRow(:final title, :final count) => _GroupHeader(
                        key: ValueKey('hdr_$title'),
                        title: title,
                        count: count,
                      ),
                    _DepotRow(:final depot) => _withFirstCardAnchor(
                        isFirst: depot.id == firstDepotId,
                        child: DepotCard(
                          key: ValueKey(depot.id),
                          depot: depot,
                          isFavorite: state.favoriteIds.contains(depot.id),
                          onTap: () => onOpenDetail(depot.id),
                          onFavoriteToggle: () => context
                              .read<DepotsBloc>()
                              .add(DepotsFavoriteToggled(depot.id)),
                          // Hidden from the list: a quotation starts from a
                          // visit. Shown only while the "quotation without a
                          // visit" lesson runs, whose step taps it — and only
                          // on a depot, as the other lists cannot quote.
                          showQuotationAction: quotationLesson &&
                              depot.listKind == DepotListKind.depot,
                          onCreateQuotationTap: () => openQuotationForDepot(
                            context,
                            depotId: depot.id,
                            depotName: context.localized(depot.displayName),
                          ),
                          quotationCoachAnchor: depot.id == firstDepotId
                              ? CoachKeys.depotFirstCardQuotation
                              : null,
                          adHocAllowed:
                              !adHocToday.contains(depot.adHocOutlet?.key),
                          onAdHocAdded: onAdHocAdded,
                        ),
                      ),
                  };
                },
              ),
            ),
          if (state.isLoadingMore && quickAccess == _QuickAccess.all)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(context.rr(16)),
                child: Center(
                    child: CircularProgressIndicator(color: scheme.primary)),
              ),
            ),
          // The system navigation bar. `paddingOf`, not `viewPaddingOf`: under
          // the shell's own bottom bar the Scaffold has already taken it, and
          // this is zero.
          // The system navigation bar, and room for Register Depot to float
          // without covering the last card.
          SliverToBoxAdapter(
            child: SizedBox(
                height: MediaQuery.paddingOf(context).bottom + context.rh(80)),
          ),
        ],
      ),
    );
  }
}

/// Anchors the App Coach's "first depot" pointer on [child] when [isFirst].
Widget _withFirstCardAnchor({required bool isFirst, required Widget child}) =>
    isFirst ? CoachKeys.wrap(CoachKeys.depotFirstCard, child: child) : child;

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({super.key, required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: context.rsp(12.5),
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
            ),
          ),
          SizedBox(width: context.rw(8)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: scheme.primary,
                fontSize: context.rsp(10.5),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          SizedBox(width: context.rw(10)),
          Expanded(child: Divider(color: colors.divider, height: 1)),
        ],
      ),
    );
  }
}

/// Registers a shop directly — a Non-BP depot when that list is on screen.
/// The new record lives on the server: on success the depots are pulled,
/// and the sync listener reloads the list.
Future<void> _registerDepot(BuildContext context) async {
  final state = context.read<DepotsBloc>().state;
  final nonBp = state is DepotsLoaded &&
      DepotAudience.of(state.filter.kind) == DepotAudience.nonBpDepots;
  final submitted = await Navigator.of(context).push<bool>(MaterialPageRoute(
    settings: const RouteSettings(name: DepotCreateScreen.routeName),
    builder: (_) => DepotCreateScreen(
      registrationType: nonBp ? DepotRegistrationType.nonBp : null,
    ),
  ));
  if (submitted == true && context.mounted) {
    unawaited(context.read<DepotSyncCubit>().refresh());
  }
}

/// Empties the search and every advanced filter, staying on the same list.
void _clearSearchAndFilters(BuildContext context, DepotsLoaded state) {
  final bloc = context.read<DepotsBloc>();
  if (state.query.isNotEmpty) bloc.add(const DepotsSearchChanged(''));
  if (!state.filter.isEmpty) {
    bloc.add(DepotsFilterChanged(
        DepotFilter(kind: state.filter.kind, sortBy: state.filter.sortBy)));
  }
}
