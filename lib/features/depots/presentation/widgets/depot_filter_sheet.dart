import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/animations/app_animations.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/depots/domain/entities/depot_filter.dart';
import 'package:steelforce/features/depots/domain/entities/depot_status.dart';
import 'package:steelforce/features/depots/presentation/bloc/depot_filter_cubit.dart';
import 'package:steelforce/features/depots/presentation/bloc/depot_filter_state.dart';
import 'package:steelforce/features/depots/presentation/widgets/depot_status_badge.dart';
import 'package:steelforce/features/depots/presentation/widgets/filter_option_group.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/shared/widgets/app_bottom_sheet.dart';

/// Opens the depot filter sheet.
///
/// [territories] and [productCategories] are the option lists; both are derived
/// from locally-synced depot rows, so this sheet works with zero
/// connectivity — nothing here awaits a network call.
void showDepotFilterSheet({
  required BuildContext context,
  required DepotFilter filter,
  required List<String> territories,
  required ValueChanged<DepotFilter> onApply,
  List<String> productCategories = const [],
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    // The sheet can grow tall on small phones once a group is expanded, so it
    // must be able to scroll rather than overflow.
    constraints: BoxConstraints(
      // sizeOf, not of(): `.of` subscribes to every metric change, so the sheet
      // rebuilt on each frame of the keyboard animation (FS-PRF-4).
      maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      maxWidth: AppBottomSheet.maxWidth,
    ),
    builder: (_) => BlocProvider(
      create: (_) => DepotFilterCubit(filter),
      child: _DepotFilterSheet(
        territories: territories,
        productCategories: productCategories,
        onApply: onApply,
      ),
    ),
  );
}

class _DepotFilterSheet extends StatelessWidget {
  const _DepotFilterSheet({
    required this.territories,
    required this.productCategories,
    required this.onApply,
  });

  final List<String> territories;
  final List<String> productCategories;
  final ValueChanged<DepotFilter> onApply;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      // Bottom inset keeps the apply button clear of the gesture bar.
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Grabber(color: colors.border),
          const _Header(),
          Flexible(
            child: ListView(
              // Dragging the form dismisses the keyboard — same gesture as every
              // other form in the app now.
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              children: [
                const _StatusGroup(),
                SizedBox(height: context.rh(10)),
                _TerritoryGroup(territories: territories),
                if (productCategories.isNotEmpty) ...[
                  SizedBox(height: context.rh(10)),
                  _ProductCategoryGroup(categories: productCategories),
                ],
                SizedBox(height: context.rh(10)),
                const _SortGroup(),
              ],
            ),
          ),
          _Actions(onApply: onApply),
        ],
      ),
    );
  }
}

class _Grabber extends StatelessWidget {
  const _Grabber({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'depots.filter_sort'.tr,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: context.rsp(17),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          // Only the badge rebuilds as criteria change — not the whole header.
          BlocSelector<DepotFilterCubit, DepotFilterState, int>(
            selector: (state) => state.activeCount,
            builder: (context, count) => AnimatedSwitcher(
              duration: AppDurations.medium,
              transitionBuilder: (child, anim) => ScaleTransition(
                scale: anim,
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: count == 0
                  ? const SizedBox.shrink(key: ValueKey('no-filters'))
                  : Container(
                      key: ValueKey<int>(count),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          color: scheme.onPrimary,
                          fontSize: context.rsp(11),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.close_rounded, color: colors.iconMuted),
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          ),
        ],
      ),
    );
  }
}

// ── Groups ────────────────────────────────────────────────────────────────
//
// Each group subscribes through BlocSelector to only the slice it renders, so
// changing the status does not rebuild the territory or sort groups.

class _StatusGroup extends StatelessWidget {
  const _StatusGroup();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<DepotFilterCubit, DepotFilterState,
        (DepotStatus?, bool)>(
      selector: (s) =>
          (s.draft.status, s.openSection == DepotFilterSection.status),
      builder: (context, data) {
        final (status, expanded) = data;
        final cubit = context.read<DepotFilterCubit>();
        return FilterOptionGroup(
          icon: Icons.flag_outlined,
          label: 'depots.status_label'.tr,
          valueLabel: status?.localizedLabel ?? 'depots.all'.tr,
          hasSelection: status != null,
          expanded: expanded,
          onToggle: () => cubit.toggleSection(DepotFilterSection.status),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChoiceChip(
                label: 'depots.all'.tr,
                selected: status == null,
                onTap: () => cubit.selectStatus(null),
              ),
              // `selectable`, not `values`: the two legacy statuses are
              // local-only and sending one as a `status` filter would ask the
              // server for a lifecycle state it does not have.
              for (final value in DepotStatus.selectable)
                FilterChoiceChip(
                  label: value.localizedLabel,
                  selected: status == value,
                  onTap: () => cubit.selectStatus(value),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _TerritoryGroup extends StatelessWidget {
  const _TerritoryGroup({required this.territories});
  final List<String> territories;

  /// Only worth showing a search field once the list is long enough that
  /// scanning it becomes work.
  static const int _searchThreshold = 8;

  @override
  Widget build(BuildContext context) {
    if (territories.isEmpty) return const SizedBox.shrink();

    return BlocSelector<DepotFilterCubit, DepotFilterState,
        (String?, bool, String)>(
      selector: (s) => (
        s.draft.territory,
        s.openSection == DepotFilterSection.territory,
        s.territoryQuery,
      ),
      builder: (context, data) {
        final (selected, expanded, query) = data;
        final cubit = context.read<DepotFilterCubit>();
        final visible = territories
            .where((t) => t.toLowerCase().contains(query.toLowerCase()))
            .toList(growable: false);

        return FilterOptionGroup(
          icon: Icons.map_outlined,
          label: 'depots.territory'.tr,
          valueLabel: selected ?? 'depots.all'.tr,
          hasSelection: selected != null,
          expanded: expanded,
          onToggle: () => cubit.toggleSection(DepotFilterSection.territory),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (territories.length >= _searchThreshold) ...[
                _SearchField(
                  initialValue: query,
                  onChanged: cubit.searchTerritory,
                ),
                SizedBox(height: context.rh(10)),
              ],
              AnimatedSwitcher(
                duration: AppDurations.medium,
                child: visible.isEmpty
                    ? _NoMatches(key: const ValueKey('territory-empty'))
                    : Wrap(
                        key: ValueKey<int>(visible.length),
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilterChoiceChip(
                            label: 'depots.all'.tr,
                            selected: selected == null,
                            onTap: () => cubit.selectTerritory(null),
                          ),
                          for (final territory in visible)
                            FilterChoiceChip(
                              label: territory,
                              selected: selected == territory,
                              onTap: () => cubit.selectTerritory(territory),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProductCategoryGroup extends StatelessWidget {
  const _ProductCategoryGroup({required this.categories});
  final List<String> categories;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<DepotFilterCubit, DepotFilterState, (String?, bool)>(
      selector: (s) => (
        s.draft.productCategory,
        s.openSection == DepotFilterSection.productCategory,
      ),
      builder: (context, data) {
        final (selected, expanded) = data;
        final cubit = context.read<DepotFilterCubit>();
        return FilterOptionGroup(
          icon: Icons.inventory_2_outlined,
          label: 'depots.product_category'.tr,
          valueLabel: selected ?? 'depots.all'.tr,
          hasSelection: selected != null,
          expanded: expanded,
          onToggle: () =>
              cubit.toggleSection(DepotFilterSection.productCategory),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChoiceChip(
                label: 'depots.all'.tr,
                selected: selected == null,
                onTap: () => cubit.selectProductCategory(null),
              ),
              for (final category in categories)
                FilterChoiceChip(
                  label: category,
                  selected: selected == category,
                  onTap: () => cubit.selectProductCategory(category),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SortGroup extends StatelessWidget {
  const _SortGroup();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<DepotFilterCubit, DepotFilterState,
        (DepotSortBy, bool)>(
      selector: (s) =>
          (s.draft.sortBy, s.openSection == DepotFilterSection.sort),
      builder: (context, data) {
        final (sort, expanded) = data;
        final cubit = context.read<DepotFilterCubit>();
        return FilterOptionGroup(
          icon: Icons.swap_vert_rounded,
          label: 'depots.sort_by'.tr,
          valueLabel: _sortLabel(sort),
          // Sort always has a value, so it never reads as an "active filter".
          hasSelection: false,
          expanded: expanded,
          onToggle: () => cubit.toggleSection(DepotFilterSection.sort),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final value in DepotSortBy.values)
                FilterChoiceChip(
                  label: _sortLabel(value),
                  selected: sort == value,
                  onTap: () => cubit.selectSort(value),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SearchField extends StatefulWidget {
  const _SearchField({required this.initialValue, required this.onChanged});
  final String initialValue;
  final ValueChanged<String> onChanged;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      style: TextStyle(fontSize: context.rsp(13), color: colors.textPrimary),
      decoration: InputDecoration(
        isDense: true,
        hintText: 'depots.search_filter_hint'.tr,
        hintStyle: TextStyle(fontSize: context.rsp(13), color: colors.textHint),
        prefixIcon: Icon(Icons.search_rounded,
            size: context.rr(18), color: colors.iconMuted),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        filled: true,
        fillColor: colors.surfaceStrong,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.border),
        ),
      ),
    );
  }
}

class _NoMatches extends StatelessWidget {
  const _NoMatches({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Text(
        'depots.no_matches'.tr,
        style:
            TextStyle(fontSize: context.rsp(12.5), color: colors.textSecondary),
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.onApply});
  final ValueChanged<DepotFilter> onApply;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: colors.divider)),
      ),
      child: BlocBuilder<DepotFilterCubit, DepotFilterState>(
        buildWhen: (a, b) =>
            a.hasChanges != b.hasChanges ||
            a.hasActiveFilters != b.hasActiveFilters,
        builder: (context, state) {
          final cubit = context.read<DepotFilterCubit>();
          return Row(
            children: [
              // Reset only appears when there is something to reset, and slides
              // away rather than popping out of the row.
              AnimatedSize(
                duration: AppDurations.medium,
                curve: AppCurves.emphasized,
                child: state.hasActiveFilters
                    ? Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: OutlinedButton(
                          onPressed: cubit.reset,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.textSecondary,
                            side: BorderSide(color: colors.border),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text('depots.reset'.tr),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              Expanded(
                child: FilledButton(
                  onPressed: state.hasChanges
                      ? () {
                          onApply(state.draft);
                          Navigator.of(context).pop();
                        }
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.primary,
                    disabledBackgroundColor:
                        scheme.primary.withValues(alpha: 0.35),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'depots.apply'.tr,
                    style: TextStyle(
                      color: scheme.onPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

String _sortLabel(DepotSortBy sort) => switch (sort) {
      DepotSortBy.recentOrder => 'depots.sort.recently_ordered'.tr,
      DepotSortBy.nameAsc => 'depots.sort.alphabetical'.tr,
      DepotSortBy.nearest => 'depots.sort.nearest'.tr,
      DepotSortBy.valueDesc => 'depots.sort.highest_value'.tr,
    };
