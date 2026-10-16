import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/features/geo_location/domain/entities/geo_address.dart';
import 'package:steelforce/features/geo_location/domain/entities/geo_unit.dart';
import 'package:steelforce/features/geo_location/domain/usecases/resolve_geo_address.dart';
import 'package:steelforce/features/geo_location/presentation/bloc/geo_location_bloc.dart';
import 'package:steelforce/features/geo_location/presentation/widgets/geo_level_field.dart';
import 'package:steelforce/features/geo_location/presentation/widgets/geo_picker_sheet.dart';
import 'package:steelforce/features/geo_location/presentation/widgets/postal_code_field.dart';

/// The whole address block — province through postal code — as one widget.
///
/// This is the reusable component of §9 and §16: a form drops it in, gets a
/// [GeoAddress] back through [onChanged], and inherits the cascade, the reset,
/// the search, the five UI states and the validation without writing any of
/// them. It owns its own bloc, so two of them on one screen (billing and
/// delivery) do not interfere.
///
/// ```dart
/// GeoLocationSelector(
///   initialCodes: ResolveGeoAddressParams(provinceCode: draft.provinceCode),
///   requirement: GeoAddressRequirement.delivery,
///   onChanged: (address) => setState(() => _address = address),
/// )
/// ```
///
/// To validate on submit, hold a [GeoLocationSelectorController] and call
/// `controller.validate()`.
class GeoLocationSelector extends StatelessWidget {
  const GeoLocationSelector({
    super.key,
    required this.onChanged,
    this.initialAddress,
    this.initialCodes,
    this.requirement = GeoAddressRequirement.standard,
    this.controller,
    this.title,
    this.showTitle = true,
    this.spacing = 16,
    this.twoColumn = false,
    this.lockPostalCode = false,
  });

  final bool twoColumn;
  final bool lockPostalCode;

  /// Fired on every change, including the resets a parent change causes — so a
  /// host form never has to derive "what did that clear?" itself.
  final ValueChanged<GeoAddress> onChanged;

  final GeoAddress? initialAddress;

  /// Codes from a saved draft. Resolved and hierarchy-checked on mount.
  final ResolveGeoAddressParams? initialCodes;

  final GeoAddressRequirement requirement;

  /// Lets the host trigger validation at submit time.
  final GeoLocationSelectorController? controller;

  final String? title;
  final bool showTitle;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<GeoLocationBloc>(
      create: (_) => GeoLocationBloc(
        ensureReady: sl(),
        getChildren: sl(),
        searchUnits: sl(),
        resolveAddress: sl(),
        requirement: requirement,
      )..add(GeoLocationStarted(
          initialAddress: initialAddress,
          initialCodes: initialCodes,
        )),
      child: _GeoLocationSelectorView(
        onChanged: onChanged,
        controller: controller,
        title: title,
        showTitle: showTitle,
        spacing: spacing,
        twoColumn: twoColumn,
        lockPostalCode: lockPostalCode,
      ),
    );
  }
}

/// Handle a host form keeps so it can validate on submit.
///
/// Deliberately not a `GlobalKey` on the state: the only thing a host needs is
/// "is this address submittable, and start showing errors if not", and exposing
/// the widget state would let a form reach into the cascade and set levels
/// directly — which is how the per-screen reimplementation this component
/// exists to prevent creeps back in.
class GeoLocationSelectorController {
  GeoLocationBloc? _bloc;

  void _attach(GeoLocationBloc bloc) => _bloc = bloc;
  void _detach() => _bloc = null;

  /// Shows any validation errors and returns whether the address can be
  /// submitted. False when the selector is not mounted — an unmounted address
  /// block has certainly not been completed.
  bool validate() => _bloc?.validateForSubmission() ?? false;

  /// The current selection, or null before the selector mounts.
  GeoAddress? get address => _bloc?.state.address;

  /// Clears every level (§8).
  void reset() => _bloc?.add(const GeoLocationReset());
}

class _GeoLocationSelectorView extends StatefulWidget {
  const _GeoLocationSelectorView({
    required this.onChanged,
    required this.controller,
    required this.title,
    required this.showTitle,
    required this.spacing,
    this.twoColumn = false,
    this.lockPostalCode = false,
  });

  final ValueChanged<GeoAddress> onChanged;
  final GeoLocationSelectorController? controller;
  final String? title;
  final bool showTitle;
  final double spacing;
  final bool twoColumn;
  final bool lockPostalCode;

  @override
  State<_GeoLocationSelectorView> createState() =>
      _GeoLocationSelectorViewState();
}

class _GeoLocationSelectorViewState extends State<_GeoLocationSelectorView> {
  @override
  void initState() {
    super.initState();
    widget.controller?._attach(context.read<GeoLocationBloc>());
  }

  @override
  void dispose() {
    widget.controller?._detach();
    super.dispose();
  }

  Future<void> _openPicker(GeoLevel level) async {
    FocusScope.of(context).unfocus();
    final bloc = context.read<GeoLocationBloc>();
    final state = bloc.state;

    // The picker is opened with a snapshot and cannot see later states, so a
    // search inside it has to be re-shown. Rebuilding the sheet on every bloc
    // state would fight the keyboard; instead the sheet reports its query, the
    // bloc reloads, and this listener pushes the new list back down.
    final result = await showModalBottomSheet<GeoPickerResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => BlocProvider<GeoLocationBloc>.value(
        value: bloc,
        child: BlocBuilder<GeoLocationBloc, GeoLocationState>(
          buildWhen: (a, b) => a.levelState(level) != b.levelState(level),
          builder: (context, s) => GeoPickerSheet(
            level: level,
            state: s.levelState(level),
            selectedCode: s.address.unitAt(level)?.code,
            onSearch: (q) => bloc.add(GeoLevelSearched(level, q)),
            onRetry: () => bloc.add(GeoLevelRetried(level)),
          ),
        ),
      ),
    );

    if (!mounted) return;

    // Clear the level's search filter on close, so reopening shows the full
    // list rather than whatever the rep last typed.
    if (state.levelState(level).query.isNotEmpty) {
      bloc.add(GeoLevelSearched(level, ''));
    }

    switch (result) {
      case GeoPickerSelection(unit: final unit):
        bloc.add(GeoLevelSelected(level, unit));
      case _ when result == GeoPickerResult.cleared:
        bloc.add(GeoLevelSelected(level, null));
      default:
        break; // dismissed — selection untouched
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocConsumer<GeoLocationBloc, GeoLocationState>(
      listenWhen: (a, b) => a.address != b.address,
      listener: (context, state) => widget.onChanged(state.address),
      builder: (context, state) {
        if (state.seedStatus == GeoSeedStatus.failure) {
          return _SeedFailure(
            message: state.seedFailureMessage,
            onRetry: () => context
                .read<GeoLocationBloc>()
                .add(const GeoLevelRetried(GeoLevel.province)),
          );
        }

        final errors = state.visibleErrors;
        String? errorFor(GeoAddressError e) =>
            errors.contains(e) ? e.messageKey.tr : null;

        // A broken hierarchy is reported on the deepest field rather than as a
        // banner: it is only reachable from bad stored data, and the actionable
        // instruction is "re-pick this", which belongs on the field.
        final hierarchyError = errors.contains(GeoAddressError.brokenHierarchy)
            ? GeoAddressError.brokenHierarchy.messageKey.tr
            : null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.showTitle) ...[
              Row(
                children: [
                  Icon(Icons.place_outlined,
                      size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    widget.title ?? 'geo.section_title'.tr,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  if (state.address != GeoAddress.empty)
                    TextButton.icon(
                      onPressed: () => context
                          .read<GeoLocationBloc>()
                          .add(const GeoLocationReset()),
                      icon: const Icon(Icons.refresh, size: 16),
                      label: Text('geo.reset'.tr),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),
              SizedBox(height: widget.spacing),
            ],
            if (widget.twoColumn) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: GeoLevelField(
                      level: GeoLevel.province,
                      levelState: state.levelState(GeoLevel.province),
                      selected: state.address.unitAt(GeoLevel.province),
                      isRequired:
                          _isRequired(GeoLevel.province, state.requirement),
                      errorText: errorFor(_missingErrorFor(GeoLevel.province)),
                      compact: true,
                      onTap: () => _openPicker(GeoLevel.province),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GeoLevelField(
                      level: GeoLevel.district,
                      levelState: state.levelState(GeoLevel.district),
                      selected: state.address.unitAt(GeoLevel.district),
                      isRequired:
                          _isRequired(GeoLevel.district, state.requirement),
                      errorText: errorFor(_missingErrorFor(GeoLevel.district)),
                      compact: true,
                      onTap: () => _openPicker(GeoLevel.district),
                    ),
                  ),
                ],
              ),
              SizedBox(height: widget.spacing),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: GeoLevelField(
                      level: GeoLevel.commune,
                      levelState: state.levelState(GeoLevel.commune),
                      selected: state.address.unitAt(GeoLevel.commune),
                      isRequired:
                          _isRequired(GeoLevel.commune, state.requirement),
                      errorText: errorFor(_missingErrorFor(GeoLevel.commune)),
                      compact: true,
                      onTap: () => _openPicker(GeoLevel.commune),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GeoLevelField(
                      level: GeoLevel.village,
                      levelState: state.levelState(GeoLevel.village),
                      selected: state.address.unitAt(GeoLevel.village),
                      isRequired:
                          _isRequired(GeoLevel.village, state.requirement),
                      errorText: errorFor(_missingErrorFor(GeoLevel.village)) ??
                          hierarchyError,
                      compact: true,
                      onTap: () => _openPicker(GeoLevel.village),
                    ),
                  ),
                ],
              ),
              SizedBox(height: widget.spacing),
              PostalCodeField(
                value: state.address.postalCode,
                isDerived:
                    widget.lockPostalCode || state.address.isPostalCodeDerived,
                isEditable:
                    widget.lockPostalCode ? false : state.isPostalCodeEditable,
                isLocked: widget.lockPostalCode,
                isRequired: state.requirement.postalCode,
                errorText: errorFor(GeoAddressError.postalCodeUnavailable),
                compact: false,
                onChanged: (v) => context
                    .read<GeoLocationBloc>()
                    .add(GeoPostalCodeEntered(v)),
              ),
            ] else ...[
              for (final level in GeoLevel.values) ...[
                GeoLevelField(
                  level: level,
                  levelState: state.levelState(level),
                  selected: state.address.unitAt(level),
                  isRequired: _isRequired(level, state.requirement),
                  errorText: errorFor(_missingErrorFor(level)) ??
                      (level == GeoLevel.village ? hierarchyError : null),
                  onTap: () => _openPicker(level),
                ),
                SizedBox(height: widget.spacing),
              ],
              PostalCodeField(
                value: state.address.postalCode,
                isDerived:
                    widget.lockPostalCode || state.address.isPostalCodeDerived,
                isEditable:
                    widget.lockPostalCode ? false : state.isPostalCodeEditable,
                isLocked: widget.lockPostalCode,
                isRequired: state.requirement.postalCode,
                errorText: errorFor(GeoAddressError.postalCodeUnavailable),
                onChanged: (v) => context
                    .read<GeoLocationBloc>()
                    .add(GeoPostalCodeEntered(v)),
              ),
            ],
          ],
        );
      },
    );
  }

  bool _isRequired(GeoLevel level, GeoAddressRequirement r) => switch (level) {
        GeoLevel.province => r.province,
        GeoLevel.district => r.district,
        GeoLevel.commune => r.commune,
        GeoLevel.village => r.village,
      };

  GeoAddressError _missingErrorFor(GeoLevel level) => switch (level) {
        GeoLevel.province => GeoAddressError.missingProvince,
        GeoLevel.district => GeoAddressError.missingDistrict,
        GeoLevel.commune => GeoAddressError.missingCommune,
        GeoLevel.village => GeoAddressError.missingVillage,
      };
}

/// The gazetteer itself could not be prepared — all four levels are unusable,
/// so the component collapses to one message and one retry rather than showing
/// four identically broken fields.
class _SeedFailure extends StatelessWidget {
  const _SeedFailure({required this.message, required this.onRetry});

  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(Icons.location_off_outlined, color: theme.colorScheme.error),
          const SizedBox(height: 12),
          Text(
            message ?? 'geo.error.seed_failed'.tr,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: onRetry,
            child: Text('common.retry'.tr),
          ),
        ],
      ),
    );
  }
}
