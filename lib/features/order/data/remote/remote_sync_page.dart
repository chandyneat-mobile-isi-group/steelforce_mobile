import 'package:steelforce/features/order/data/models/product_model.dart';

class RemoteSyncPage {
  const RemoteSyncPage({required this.items, required this.hasMore});
  final List<ProductModel> items;
  final bool hasMore;
}

class RemoteDeltaPage {
  const RemoteDeltaPage({required this.upserted, required this.deletedIds});
  final List<ProductModel> upserted;
  final List<String> deletedIds;
}
