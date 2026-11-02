import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/depots/data/models/registration/draft_json.dart';
import 'package:steelforce/features/depots/domain/entities/registration/depot_reference_lists.dart';

/// Reads `data` of `GET /api/v1/depots/references` and the profile lists.
///
/// Every code stays text. An item without a code is dropped — it could be
/// shown but never submitted. A missing list reads as empty, which the form
/// already treats as "not synced yet".
abstract final class DepotReferenceListsModel {
  static DepotReferenceLists fromJson(DataMap json) => DepotReferenceLists(
        salesOrgs: _options(json['salesOrgs']),
        distributionChannels: _options(json['distributionChannels']),
        customerGroups: _options(json['customerGroups']),
        salesOffices: _options(json['salesOffices']),
        shippingConditions: _options(json['shippingConditions']),
        paymentTerms: _options(json['paymentTerms']),
      );

  static List<ReferenceOption> _options(Object? raw) => [
        for (final item in DraftJson.maps(raw))
          if (DraftJson.string(item['code']) case final code?)
            ReferenceOption(code: code, name: DraftJson.string(item['name'])),
      ];

  /// `data` of `GET /api/v1/profile-lists/{branch|factory}` — a bare array of
  /// `ProfileListValueView`.
  static List<SupplierOption> suppliersFromJson(Object? raw) => [
        for (final item in DraftJson.maps(raw))
          if (DraftJson.string(item['code']) case final code?)
            SupplierOption(
              code: code,
              nameEn: DraftJson.string(item['nameEn']) ?? code,
              nameKh: DraftJson.string(item['nameKh']),
              isActive: item['isActive'] != false,
            ),
      ];
}
