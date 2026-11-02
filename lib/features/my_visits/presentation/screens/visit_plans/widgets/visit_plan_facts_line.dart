import 'package:flutter/material.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/features/depots/domain/usecases/get_depot_channel.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_plan.dart';

/// `territory · channel · tier` under a visit plan's name — the same line a
/// depot card shows. The plans API sends no channel, so it is the depot's own
/// from the depots API, found by the plan's depot code (a Non-BP depot by its
/// id); "Null" when this device does not hold that depot.
class VisitPlanFactsLine extends StatefulWidget {
  const VisitPlanFactsLine({
    super.key,
    required this.plan,
    required this.style,
    required this.orNull,
  });

  final VisitPlan plan;
  final TextStyle style;

  /// The card's own rendering of a value, "Null" when absent.
  final String Function(String?) orNull;

  @override
  State<VisitPlanFactsLine> createState() => _VisitPlanFactsLineState();
}

class _VisitPlanFactsLineState extends State<VisitPlanFactsLine> {
  String? _channel;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(VisitPlanFactsLine old) {
    super.didUpdateWidget(old);
    if (old.plan.depotCode != widget.plan.depotCode ||
        old.plan.nonDepotId != widget.plan.nonDepotId) {
      _load();
    }
  }

  Future<void> _load() async {
    if (!sl.isRegistered<GetDepotChannel>()) return;
    final result = await sl<GetDepotChannel>()((
      depotCode: widget.plan.depotCode,
      depotId: widget.plan.nonDepotId,
    ));
    if (!mounted) return;
    setState(() => _channel = switch (result) {
          Success(:final data) => data,
          Failed() => null,
        });
  }

  @override
  Widget build(BuildContext context) => Text(
        [widget.plan.territoryCode, _channel, widget.plan.depotTier]
            .map(widget.orNull)
            .join(' · '),
        style: widget.style,
      );
}
