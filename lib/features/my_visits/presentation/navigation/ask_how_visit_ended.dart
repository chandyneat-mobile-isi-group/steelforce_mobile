import 'package:flutter/widgets.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/features/my_visits/domain/entities/check_out_outcome.dart';
import 'package:steelforce/features/my_visits/domain/entities/no_order_reason.dart';
import 'package:steelforce/features/my_visits/domain/usecases/get_check_out_context.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/check_out_reasons_cubit.dart';
import 'package:steelforce/features/my_visits/presentation/widgets/check_out/check_out_sheet.dart';

/// What the rep decided at check-out.
class CheckOutDecision {
  const CheckOutDecision(this.choice);

  /// Null when there was no checked-in visit to describe — the caller still
  /// completes, which only clears a stale pointer.
  final CheckOutChoice? choice;
}

/// Every "end this visit" control asks this first: with an order or without.
/// Resolves to null when the rep backs out, and the visit stays open.
Future<CheckOutDecision?> askHowVisitEnded(BuildContext context) async {
  final visit = (await sl<GetCheckOutContext>()(const NoParams()))
      .when(success: (c) => c, failure: (_) => null);
  if (visit == null) return const CheckOutDecision(null);
  if (!context.mounted) return null;

  // Loading starts now, so the reasons are usually there by the time the rep
  // switches to "without order".
  final reasons = sl<CheckOutReasonsCubit>()..load();
  try {
    final choice =
        await showCheckOutSheet(context, visit: visit, reasons: reasons);
    return choice == null ? null : CheckOutDecision(choice);
  } finally {
    await reasons.close();
  }
}

/// How a visit ends when the rep is not asked: with every order taken at the
/// stop, or — with none — "other", noting that no reason was asked.
///
/// TODO(release-gate): demo-only. The server needs the rep's real answer;
/// live builds must keep [askHowVisitEnded].
Future<CheckOutDecision> visitEndedWithoutAsking() async {
  final visit = (await sl<GetCheckOutContext>()(const NoParams()))
      .when(success: (c) => c, failure: (_) => null);
  if (visit == null) return const CheckOutDecision(null);
  if (visit.orders.isNotEmpty) {
    return CheckOutDecision(CheckOutChoice.withOrder(
        [for (final order in visit.orders) order.ref]));
  }
  return const CheckOutDecision(CheckOutChoice.withoutOrder(
    reason: NoOrderReason.otherCode,
    noOrderNote: unaskedCheckOutNote,
  ));
}

/// Stored with the check-out, so the record says why it has no real reason.
/// Data, not UI text: it is not translated.
const String unaskedCheckOutNote =
    'Completed from the demo app (no reason asked)';
