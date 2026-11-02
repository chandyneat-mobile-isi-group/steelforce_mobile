import 'package:steelforce/features/depots/data/models/sap_reference_options.dart';
import 'package:steelforce/features/depots/data/remote/depot_datasources.dart';
import 'package:steelforce/features/depots/domain/entities/registration/depot_reference_lists.dart';

/// The six lists of `GET /api/v1/depots/references` in the catalogue shape
/// the wizard's dropdowns and the offline cache already read.
///
/// Customer groups fill the form's `DepotGroup` dropdown — the same SAP list
/// under the form's older name. Division, sales group and price group are not
/// in this response; their dropdowns keep the built-in lists
/// ([SapReferenceOptions.forCatalogue]). An empty list is left out, so its
/// dropdown falls back instead of offering nothing.
extension DepotReferenceListsToCatalogue on DepotReferenceLists {
  DepotReferenceCatalogue toCatalogue() => DepotReferenceCatalogue({
        'catalogues': {
          for (final (name, options) in [
            (SapCatalogue.salesOrg, salesOrgs),
            (SapCatalogue.distributionChannel, distributionChannels),
            (SapCatalogue.depotGroup, customerGroups),
            (SapCatalogue.salesOffice, salesOffices),
            (SapCatalogue.shippingCondition, shippingConditions),
            (SapCatalogue.paymentTerm, paymentTerms),
          ])
            if (options.isNotEmpty)
              name: [
                for (final o in options)
                  {'code': o.code, 'name': o.name ?? o.code},
              ],
        },
      });
}
