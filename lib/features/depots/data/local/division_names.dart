import 'package:steelforce/features/depots/data/models/bp_depot_form_data.dart';
import 'package:steelforce/features/depots/data/models/sap_reference_options.dart';
import 'package:steelforce/features/depots/data/remote/depot_datasources.dart';

/// Names a SAP division code for display — `10` → `ISI Steel`.
///
/// The server's division list as last cached ([_catalogue]), else the list
/// the app ships with. Offline and synchronous: it never fetches.
class DivisionNames {
  const DivisionNames(this._catalogue);

  /// The cached reference catalogue, retired codes included so a value
  /// stored before it was retired still reads; null when none is cached.
  final DepotReferenceCatalogue? Function() _catalogue;

  String? nameOf(String? code) {
    final wanted = code?.trim() ?? '';
    if (wanted.isEmpty) return null;
    for (final option in [
      ...SapReferenceOptions(_catalogue()).division,
      ...SapMasterData.division,
    ]) {
      if (option.code == wanted) return option.labelEn;
    }
    return null;
  }
}
