import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/data/models/category_filter_schema_model.dart';

/// The four reads that make up the guided material finder.
///
/// One method per level the rep is standing on, mirroring
/// `/api/v1/mobile/materials/selection/*` exactly. There is no "fetch
/// everything" method here for the same reason there is none on the server:
/// the live master is 13,499 materials, and a screen that scrolls it is the
/// design mistake this whole surface replaces.
///
/// All four read the platform's own synced copy of the material master, so none
/// of them touches SAP and none can fail because the ERP is down.
abstract interface class MaterialSelectionRemoteDataSource {
  /// Stage zero. Small, and the only thing loaded when the finder opens.
  Future<List<DataMap>> fetchCategories({bool includeBlocked = false});

  /// The wizard's shape. Configuration rather than catalogue data — around
  /// 9.5 KB for every published hierarchy — so it is fetched once per session
  /// and held.
  ///
  /// Omit [categoryCode] for every published hierarchy; supply one to get that
  /// category, deriving a hierarchy when none is published. Derivation runs
  /// only for a named category: doing it for all 49 would turn a small
  /// configuration read into dozens of aggregates.
  Future<List<CategoryFilterSchemaModel>> fetchSchemas({String? categoryCode});

  /// The options for exactly one step, given everything answered so far.
  ///
  /// Body shape is `{attribute, selection}` — **not** the same as
  /// [fetchMaterials]. Mixing the two is silently read as an empty selection
  /// rather than rejected.
  Future<List<DataMap>> fetchFacetOptions({
    required String attribute,
    required Map<String, dynamic> selection,
  });

  /// The terminal read. Body shape is `{selection, page, pageSize, search}` —
  /// putting the selection fields at the top level here means no selection at
  /// all.
  ///
  /// Refuses an unbounded request with `Material.SelectionNotBounded`. Callers
  /// must prevent that rather than catch it.
  Future<MaterialPage> fetchMaterials({
    required Map<String, dynamic> selection,
    required int page,
    required int pageSize,
    String? search,
  });

  /// Banded on-hand stock for one material.
  ///
  /// The read the order flow actually gates on. Unlike [fetchAvailability] it
  /// needs no sales-area parameters, so it answers a real verdict rather than
  /// a complaint about missing input — which is why this, not that, is what
  /// decides whether a rep may set a quantity.
  ///
  /// Returns a band (`High` / `Medium` / `Low` / `None`) and a per-plant
  /// breakdown. Never a quantity: there is no on-hand figure anywhere in this
  /// API, by design.
  Future<DataMap> fetchStock(String material);

  /// SAP's live sellability verdict for one material.
  ///
  /// The odd one out in this interface: the other four read the platform's own
  /// synced copy and cannot fail because the ERP is down. This one *is* the
  /// ERP, so it is slow, it can time out, and it is spent on commitment rather
  /// than on browsing.
  ///
  /// The sales-area triple is optional on the wire and mandatory in SAP.
  /// Omitting it does not produce an error — it produces a **200** carrying
  /// `isSellable: false` and `INPUT_*` checks, which is the absence of an
  /// answer shaped like one. Callers must be able to tell the two apart.
  Future<DataMap> fetchAvailability(
    String material, {
    String? salesOrg,
    String? disChannel,
    String? division,
    String? plant,
  });
}

/// One page of the terminal read, with the server's own paging verdict.
///
/// [hasMore] is read back from `metadata` rather than inferred from the row
/// count: `pageSize` is clamped rather than rejected, so what was asked for is
/// not necessarily what was used.
class MaterialPage {
  const MaterialPage({
    required this.rows,
    required this.hasMore,
    required this.totalRecords,
  });

  final List<DataMap> rows;
  final bool hasMore;
  final int totalRecords;
}
