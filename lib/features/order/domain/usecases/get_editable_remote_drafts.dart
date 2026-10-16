import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/domain/entities/quotation_api_entities.dart';
import 'package:steelforce/features/order/domain/services/quotation_admin_gateway.dart';

/// The rep's still-editable quotations on the Admin backend (`Draft` and
/// `Returned`), for the Continue Working card. Fails with a
/// [NetworkFailure]-shaped result when the backend cannot be read; the card
/// then simply shows the device's own drafts.
class GetEditableRemoteDrafts
    extends UseCase<List<QuotationSummary>, NoParams> {
  const GetEditableRemoteDrafts(this._gateway);
  final QuotationAdminGateway _gateway;

  @override
  ResultFuture<List<QuotationSummary>> call(NoParams params) async {
    try {
      return Success(await _gateway.fetchEditableDrafts());
    } catch (_) {
      return const Failed(NetworkFailure());
    }
  }
}
