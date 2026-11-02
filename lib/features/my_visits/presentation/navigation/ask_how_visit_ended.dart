import 'package:flutter/widgets.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/features/my_visits/domain/entities/check_out_outcome.dart';
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
