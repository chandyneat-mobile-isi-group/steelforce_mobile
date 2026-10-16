import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/domain/entities/no_order_reason.dart';
import 'package:steelforce/features/my_visits/domain/repositories/check_out_reason_repository.dart';

class GetCheckOutReasons extends UseCase<List<NoOrderReason>, NoParams> {
  const GetCheckOutReasons(this._repository);
  final CheckOutReasonRepository _repository;
  @override
  ResultFuture<List<NoOrderReason>> call(NoParams params) async =>
      Success(await _repository.getReasons());
}
