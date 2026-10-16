import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/localization/localized_text_context.dart';
import 'package:steelforce/features/geo_location/domain/entities/geo_unit.dart';
import 'package:steelforce/features/geo_location/presentation/bloc/geo_location_bloc.dart';

/// One level's field: a label, a tappable value, and whatever state it is in.
///
/// The five UI states of §11 are rendered here and nowhere else. The four
/// levels differ only in their label and their locked hint, both of which are
/// data — so `ProvinceSelector`, `DistrictSelector`, `CommuneSelector` and
/// `VillageSelector` would be four copies of this file differing by a string.
/// The named constructors give call sites the same readability without the
/// duplication.
class GeoLevelField extends StatelessWidget {
  const GeoLevelField({
    super.key,
    required this.level,
    required this.levelState,
    required this.selected,
    required this.onTap,
    this.errorText,
    this.isRequired = false,
    this.compact = false,
  });

  final GeoLevel level;
  final GeoLevelState levelState;
  final GeoUnit? selected;
  final VoidCallback onTap;
  final String? errorText;
  final bool isRequired;
  final bool compact;

  bool get _isLocked => levelState.status == GeoLevelStatus.locked;
  bool get _isLoading => levelState.status == GeoLevelStatus.loading;
  bool get _hasFailed => levelState.status == GeoLevelStatus.failure;

  /// Disabled while locked or loading. Not while failed — a failed field must
  /// stay tappable, because the retry lives inside the sheet it opens.
  bool get _isEnabled => !_isLocked && !_isLoading;

  IconData get _icon => switch (level) {
        GeoLevel.province => Icons.account_balance_outlined,
        GeoLevel.district => Icons.location_on_outlined,
        GeoLevel.commune => Icons.groups_outlined,
        GeoLevel.village => Icons.home_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasError = errorText != null;

    final card = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasError ? theme.colorScheme.error : const Color(0xFFE2E8F0),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Icon(
                          _icon,
                          color: theme.colorScheme.primary,
                          size: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: RichText(
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        text: TextSpan(
                          text: level.labelKey.tr,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                          children: [
                            if (isRequired)
                              TextSpan(
                                text: ' *',
                                style: TextStyle(
                                  color: theme.colorScheme.error,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Semantics(
                  button: true,
                  enabled: _isEnabled,
                  label: level.labelKey.tr,
                  value: _valueLabel(context),
                  child: InkWell(
                    onTap: _isEnabled
                        ? () {
                            FocusScope.of(context).unfocus();
                            onTap();
                          }
                        : null,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _isLocked
                            ? const Color(0xFFF1F5F9)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _valueLabel(context),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: selected != null
                                    ? theme.colorScheme.onSurface
                                    : const Color(0xFF94A3B8),
                                fontWeight: selected != null
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          _suffix(theme),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Icon(
                      _icon,
                      color: theme.colorScheme.primary,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RichText(
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        text: TextSpan(
                          text: level.labelKey.tr,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                          children: [
                            if (isRequired)
                              TextSpan(
                                text: ' *',
                                style: TextStyle(
                                  color: theme.colorScheme.error,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 5),
                      Semantics(
                        button: true,
                        enabled: _isEnabled,
                        label: level.labelKey.tr,
                        value: _valueLabel(context),
                        child: InkWell(
                          onTap: _isEnabled
                              ? () {
                                  FocusScope.of(context).unfocus();
                                  onTap();
                                }
                              : null,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: _isLocked
                                  ? const Color(0xFFF1F5F9)
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _valueLabel(context),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: selected != null
                                          ? theme.colorScheme.onSurface
                                          : const Color(0xFF94A3B8),
                                      fontWeight: selected != null
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                _suffix(theme),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );

    if (hasError || _hasFailed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          card,
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              errorText ?? 'geo.error.load_failed'.tr,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    }
    return card;
  }

  Widget _suffix(ThemeData theme) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_hasFailed) {
      return Icon(Icons.error_outline, color: theme.colorScheme.error);
    }
    if (selected != null) {
      return Icon(Icons.check_circle, color: theme.colorScheme.primary);
    }
    return Icon(
      Icons.keyboard_arrow_down,
      color: _isLocked
          ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
          : theme.colorScheme.onSurfaceVariant,
    );
  }

  /// The value, or the state-appropriate placeholder. A locked field says which
  /// level to fill in first rather than a generic "select" — that hint is the
  /// only thing telling a rep why the field will not open.
  String _valueLabel(BuildContext context) {
    if (selected != null) return context.localized(selected!.name);
    if (_isLoading) return 'geo.loading'.tr;
    if (_isLocked) {
      return switch (level) {
        GeoLevel.province => 'geo.locked.province',
        GeoLevel.district => 'geo.locked.district',
        GeoLevel.commune => 'geo.locked.commune',
        GeoLevel.village => 'geo.locked.village',
      }
          .tr;
    }
    return switch (level) {
      GeoLevel.province => 'geo.hint.province',
      GeoLevel.district => 'geo.hint.district',
      GeoLevel.commune => 'geo.hint.commune',
      GeoLevel.village => 'geo.hint.village',
    }
        .tr;
  }
}
