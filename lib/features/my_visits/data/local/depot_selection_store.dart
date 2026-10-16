import 'package:hive_flutter/hive_flutter.dart';

/// Remembers the rep's last-selected depot/shop for the Depot Stock flow so the
/// selection screen can pre-highlight it on return (the user is still free to
/// pick another). Backed by the shared Hive cache box, mirroring
/// `CatalogFilterStore`.
class DepotSelectionStore {
  const DepotSelectionStore(this._box);
  final Box<dynamic> _box;

  static const _kLastShopId = 'depot_last_shop_id';

  String? get lastShopId => _box.get(_kLastShopId) as String?;

  Future<void> saveLastShopId(String shopId) => _box.put(_kLastShopId, shopId);
}
