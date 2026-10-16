import 'dart:async';

import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/localization/localized_text_context.dart';
import 'package:steelforce/features/geo_location/domain/entities/geo_unit.dart';
import 'package:steelforce/features/geo_location/presentation/bloc/geo_location_bloc.dart';

/// The searchable modal list behind every level of the selector.
///
/// ## Why a sheet and not a `DropdownButton`
///
/// A Material dropdown cannot host a search field, and it renders its menu in
/// an overlay sized to the button — which for 203 districts is a scroll of
/// eight visible rows over the field the rep is trying to read. A bottom sheet
/// gets a real search box, a comfortable row height for Khmer script (which
/// needs more line height than Latin), and it pushes the keyboard and the list
/// into the same place every time regardless of where the field sits on the
/// form.
///
/// It is stateless with respect to selection: it reports a [GeoUnit] and closes.
/// The bloc owns what that means.
class GeoPickerSheet extends StatefulWidget {
  const GeoPickerSheet({
    super.key,
    required this.level,
    required this.state,
    required this.onSearch,
    required this.onRetry,
    this.selectedCode,
  });

  final GeoLevel level;
  final GeoLevelState state;
  final ValueChanged<String> onSearch;
  final VoidCallback onRetry;
  final String? selectedCode;

  @override
  State<GeoPickerSheet> createState() => _GeoPickerSheetState();
}

/// What the sheet came back with.
sealed class GeoPickerResult {
  const GeoPickerResult();
  static const GeoPickerResult cleared = _Cleared();
}

final class GeoPickerSelection extends GeoPickerResult {
  const GeoPickerSelection(this.unit);
  final GeoUnit unit;
}

final class _Cleared extends GeoPickerResult {
  const _Cleared();
}

class _GeoPickerSheetState extends State<GeoPickerSheet> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.state.query;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// 200 ms. Long enough that a normal typing rhythm produces one query per
  /// word rather than one per letter; short enough that the list feels like it
  /// is tracking the keyboard. The queries are local, so this is about avoiding
  /// list churn under the rep's finger, not about saving a network round trip.
  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (mounted) widget.onSearch(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);

    return Padding(
      // The keyboard inset, so the search field and the first few results stay
      // above it on a small handset.
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SizedBox(
        height: media.size.height * 0.75,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color:
                    theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.level.labelKey.tr,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (widget.selectedCode != null)
                    TextButton(
                      onPressed: () =>
                          Navigator.of(context).pop(GeoPickerResult.cleared),
                      child: Text('geo.clear'.tr),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'common.close'.tr,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _controller,
                autofocus: widget.state.units.length > 12,
                textInputAction: TextInputAction.search,
                onChanged: _onChanged,
                decoration: InputDecoration(
                  hintText: 'geo.search_hint'.tr,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _controller.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _controller.clear();
                            widget.onSearch('');
                            setState(() {});
                          },
                        ),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: _body(theme)),
          ],
        ),
      ),
    );
  }

  Widget _body(ThemeData theme) {
    switch (widget.state.status) {
      case GeoLevelStatus.loading:
        return const Center(child: CircularProgressIndicator());

      case GeoLevelStatus.failure:
        return _Message(
          icon: Icons.cloud_off,
          text: widget.state.failureMessage ?? 'geo.error.load_failed'.tr,
          action: FilledButton.tonal(
            onPressed: () {
              widget.onRetry();
              Navigator.of(context).pop();
            },
            child: Text('common.retry'.tr),
          ),
        );

      case GeoLevelStatus.locked:
        return _Message(
          icon: Icons.lock_outline,
          text: _lockedHint(widget.level),
        );

      case GeoLevelStatus.ready:
        if (widget.state.units.isEmpty) {
          return _Message(
            icon: Icons.search_off,
            text: widget.state.isEmptyBecauseOfSearch
                ? 'geo.empty.no_matches'.tr
                : _emptyHint(widget.level),
          );
        }
        return ListView.builder(
          // The list is short (25 provinces, at most 33 villages), but
          // `.builder` costs nothing extra and keeps the widget honest if a
          // future gazetteer has a district with far more communes.
          itemCount: widget.state.units.length,
          itemBuilder: (context, i) {
            final unit = widget.state.units[i];
            final isSelected = unit.code == widget.selectedCode;
            return ListTile(
              title: Text(context.localized(unit.name)),
              subtitle: Text(
                unit.postalCode == null
                    ? unit.unit
                    : '${unit.unit} · ${unit.postalCode}',
                style: theme.textTheme.bodySmall,
              ),
              trailing: isSelected
                  ? Icon(Icons.check, color: theme.colorScheme.primary)
                  : null,
              selected: isSelected,
              onTap: () => Navigator.of(context).pop(GeoPickerSelection(unit)),
            );
          },
        );
    }
  }

  String _lockedHint(GeoLevel level) => switch (level) {
        GeoLevel.province => 'geo.locked.province',
        GeoLevel.district => 'geo.locked.district',
        GeoLevel.commune => 'geo.locked.commune',
        GeoLevel.village => 'geo.locked.village',
      }
          .tr;

  String _emptyHint(GeoLevel level) => switch (level) {
        GeoLevel.province => 'geo.empty.provinces',
        GeoLevel.district => 'geo.empty.districts',
        GeoLevel.commune => 'geo.empty.communes',
        GeoLevel.village => 'geo.empty.villages',
      }
          .tr;
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
