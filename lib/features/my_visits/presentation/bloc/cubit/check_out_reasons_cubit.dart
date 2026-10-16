import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/features/my_visits/domain/entities/no_order_reason.dart';
import 'package:steelforce/features/my_visits/domain/usecases/get_check_out_reasons.dart';

/// The "no order" reasons for the check-out sheet. Null while loading.
///
/// Never ends in an error: the repository falls back to the cached list, and
/// at worst to `other` alone, so the rep can always close a visit.
class CheckOutReasonsCubit extends Cubit<List<NoOrderReason>?> {
  CheckOutReasonsCubit(this._get) : super(null);

  final GetCheckOutReasons _get;

  Future<void> load() async {
    final result = await _get(const NoParams());
    if (isClosed) return;
    emit(result.when(
      success: (reasons) => reasons,
      failure: (_) => const [NoOrderReason.other],
    ));
  }
}
