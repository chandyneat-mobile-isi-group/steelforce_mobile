import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/depots/domain/entities/business_partner_request.dart';
import 'package:steelforce/features/depots/domain/entities/business_partner_result.dart';
import 'package:steelforce/features/depots/domain/repositories/business_partner_repository.dart';

/// Registers a Business Partner in SAP in one call.
///
/// Replaces the `CreateDepot` → draft → submit sequence for the mobile
/// registration flow. `CreateDepot` stays for callers that want a local
/// `Draft` depot without touching SAP; this one is the SAP write.
class CreateBusinessPartner
    extends UseCase<BusinessPartnerResult, BusinessPartnerRequest> {
  const CreateBusinessPartner(this._repository);

  final BusinessPartnerRepository _repository;

  @override
  ResultFuture<BusinessPartnerResult> call(BusinessPartnerRequest params) =>
      _repository.createBusinessPartner(params);
}

/// Dry-runs the registration (`Commit: false`) so the rep learns about a SAP
/// rejection while still standing in the shop, not an hour later from HQ.
class ValidateBusinessPartner
    extends UseCase<BusinessPartnerResult, BusinessPartnerRequest> {
  const ValidateBusinessPartner(this._repository);

  final BusinessPartnerRepository _repository;

  @override
  ResultFuture<BusinessPartnerResult> call(BusinessPartnerRequest params) =>
      _repository.validateBusinessPartner(params);
}
