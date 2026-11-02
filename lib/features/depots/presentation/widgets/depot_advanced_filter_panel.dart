import 'package:flutter/material.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/features/depots/domain/entities/depot_filter.dart';
import 'package:steelforce/features/depots/domain/entities/depot_filter_options.dart';
import 'package:steelforce/features/depots/domain/entities/depot_status.dart';
import 'package:steelforce/features/depots/domain/usecases/load_depot_filter_options.dart';
import 'package:steelforce/features/depots/presentation/widgets/depot_filter_field.dart';
import 'package:steelforce/features/depots/presentation/widgets/depot_status_badge.dart';

/// Status, Region and Type for the list on screen, applied together.
///
/// Each list offers only values its depots carry — read from this device, so
/// it works offline. Nothing changes until **Apply Filters**; **Clear**
/// empties all three at once.
class DepotAdvancedFilterPanel extends StatefulWidget {
  const DepotAdvancedFilterPanel({
    super.key,
    required this.filter,
    required this.onApply,
  });

  /// The list's current filter; its kind picks the choices.
  final DepotFilter filter;
  final ValueChanged<DepotFilter> onApply;

  @override
  State<DepotAdvancedFilterPanel> createState() => _PanelState();
}

class _PanelState extends State<DepotAdvancedFilterPanel> {
  late DepotStatus? _status = widget.filter.status;
  late String? _province = widget.filter.province;
  late String? _channel = widget.filter.channel;
  late Future<DepotFilterOptions> _options = _load();

  Future<DepotFilterOptions> _load() async =>
      switch (await sl<LoadDepotFilterOptions>()(widget.filter.kind)) {
        Success(:final data) => data,
        Failed() => const DepotFilterOptions(),
      };

  @override
  void didUpdateWidget(DepotAdvancedFilterPanel old) {
    super.didUpdateWidget(old);
    if (old.filter.kind != widget.filter.kind) _options = _load();
  }

  void _apply() => widget.onApply(widget.filter.copyWith(
        status: () => _status,
        province: () => _province,
        channel: () => _channel,
      ));

  void _clear() => setState(() {
        _status = null;
        _province = null;
        _channel = null;
      });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.fromLTRB(
          context.rw(14), context.rh(12), context.rw(14), context.rh(14)),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
        boxShadow: colors.cardShadow,
      ),
      child: FutureBuilder<DepotFilterOptions>(
        future: _options,
        builder: (context, snapshot) {
          final options = snapshot.data ?? const DepotFilterOptions();
          final gap = SizedBox(height: context.rh(10));
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.tune_rounded,
                      size: context.rr(18), color: scheme.primary),
                  SizedBox(width: context.rw(8)),
                  // Flexible: a long Khmer title or large text wraps.
                  Flexible(
                    child: Text(
                      'depots.filters.advanced'.tr,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: context.rsp(14),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.rh(12)),
              DepotFilterField<DepotStatus>(
                label: 'depots.filters.status'.tr,
                icon: Icons.verified_outlined,
                value: _status,
                options: options.statuses,
                display: (s) => s.localizedLabel,
                onChanged: (v) => setState(() => _status = v),
              ),
              gap,
              DepotFilterField<String>(
                label: 'depots.filters.region'.tr,
                icon: Icons.location_on_outlined,
                value: _province,
                options: options.provinces,
                display: (v) => v,
                onChanged: (v) => setState(() => _province = v),
              ),
              gap,
              DepotFilterField<String>(
                label: 'depots.filters.type'.tr,
                icon: Icons.storefront_outlined,
                value: _channel,
                options: options.channels,
                display: (v) => v,
                onChanged: (v) => setState(() => _channel = v),
              ),
              SizedBox(height: context.rh(14)),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _clear,
                      style: OutlinedButton.styleFrom(
                        minimumSize: Size.fromHeight(context.rh(44)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('depots.filters.clear'.tr),
                    ),
                  ),
                  SizedBox(width: context.rw(10)),
                  Expanded(
                    child: FilledButton(
                      onPressed: _apply,
                      style: FilledButton.styleFrom(
                        minimumSize: Size.fromHeight(context.rh(44)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('depots.filters.apply'.tr),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
