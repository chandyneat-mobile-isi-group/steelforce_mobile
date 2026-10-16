import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/domain/entities/check_out_record.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_send_result.dart';
import 'package:steelforce/features/my_visits/domain/repositories/visit_repository.dart';

/// Offers a check-out already saved on the device to the server now. Held
/// back while its check-in has not reached the server.
class SendCheckOut extends UseCase<VisitSendResult, CheckOutRecord> {
  const SendCheckOut(this._repository);
  final VisitRepository _repository;
  @override
  ResultFuture<VisitSendResult> call(CheckOutRecord params) =>
      _repository.sendCheckOut(params);
}
