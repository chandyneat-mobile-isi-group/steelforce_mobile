import 'package:flutter/material.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/features/depots/domain/entities/depot.dart';
import 'package:steelforce/features/order/domain/entities/credit_summary.dart';
import 'package:steelforce/features/order/domain/usecases/catalog_params.dart';
import 'package:steelforce/features/order/domain/usecases/get_credit_summary.dart';
import 'package:steelforce/features/order/presentation/widgets/quotation/credit_summary_card.dart';

/// The depot's credit position above the product finder. Fetched once when
/// the builder opens; renders nothing until it answers, and nothing at all if
/// it fails — the rep can still quote without it.
class DepotCreditSummary extends StatefulWidget {
  const DepotCreditSummary({super.key, required this.depot});

  final Depot depot;

  @override
  State<DepotCreditSummary> createState() => _DepotCreditSummaryState();
}

class _DepotCreditSummaryState extends State<DepotCreditSummary> {
  late final Future<CreditSummary?> _summary = sl<GetCreditSummary>()(
    GetCreditSummaryParams(widget.depot.id),
  ).then((result) => result.when(success: (s) => s, failure: (_) => null));

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: FutureBuilder<CreditSummary?>(
        future: _summary,
        builder: (_, snapshot) => snapshot.data == null
            ? const SizedBox.shrink()
            : CreditSummaryCard(
                creditLimit: widget.depot.creditLimit,
                summary: snapshot.data!,
              ),
      ),
    );
  }
}
