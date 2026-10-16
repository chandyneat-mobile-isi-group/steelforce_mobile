import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/domain/entities/check_in_record.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_send_result.dart';
import 'package:steelforce/features/my_visits/domain/repositories/visit_repository.dart';

/// Offers a check-in already saved on the device to the server now. Offline
/// it simply stays queued for the next sync.
class SendCheckIn extends UseCase<VisitSendResult, CheckInRecord> {
  const SendCheckIn(this._repository);
  final VisitRepository _repository;
  @override
  ResultFuture<VisitSendResult> call(CheckInRecord params) =>
      _repository.sendCheckIn(params);
}
