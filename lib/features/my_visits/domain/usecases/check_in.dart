import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/domain/entities/check_in_record.dart';
import 'package:steelforce/features/my_visits/domain/repositories/visit_repository.dart';

class CheckIn extends UseCase<CheckInRecord, CheckInRecord> {
  const CheckIn(this._repository);
  final VisitRepository _repository;
  @override
  ResultFuture<CheckInRecord> call(CheckInRecord params) =>
      _repository.checkIn(params);
}
