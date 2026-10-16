import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/domain/entities/check_out_record.dart';
import 'package:steelforce/features/my_visits/domain/repositories/visit_repository.dart';

class CheckOut extends UseCase<CheckOutRecord, CheckOutRecord> {
  const CheckOut(this._repository);
  final VisitRepository _repository;
  @override
  ResultFuture<CheckOutRecord> call(CheckOutRecord params) =>
      _repository.checkOut(params);
}
