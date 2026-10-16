import 'package:drift/drift.dart';

/// Local, ephemeral shopping cart (Blueprint Layer 1, local-only — never
/// synced). Ported from `catalog.db`. [createdAt] is kept as ISO **text** (not
/// a DateTimeColumn) to preserve the exact `DataMap` row contract the cart
/// repository already reads/writes, so the cutover needs no repository change.
class CartItems extends Table {
  @override
  String get tableName => 'cart_items';

  TextColumn get id => text()();
  TextColumn get productId => text()();
  RealColumn get quantity => real()();
  TextColumn get unit => text()();
  RealColumn get discountPercent => real().withDefault(const Constant(0))();
  TextColumn get leadId => text().nullable()();
  TextColumn get depotId => text().nullable()();
  TextColumn get editingQuotationId => text().nullable()();

  /// JSON blob describing a customized line (measurements, appearance, drawing
  /// path, notes), or null for a plain catalog line. Free-form so the
  /// customization shape can evolve without a schema change — see
  /// `ProductCustomizationSpec.encode`.
  TextColumn get customizationJson => text().nullable()();

  /// The unit price agreed when the line was added, frozen against later
  /// catalog deltas.
  ///
  /// Nullable, and null means "no snapshot — price this line from the live
  /// `prices` row", which is precisely what every row did before this column
  /// existed. That is what lets the v17 migration add it without rewriting a
  /// single existing cart line.
  RealColumn get unitPrice => real().nullable()();

  /// JSON blob of the line's pickup/delivery terms, or null for a line added
  /// straight off the product grid. Free-form for the same reason
  /// [customizationJson] is: the shape is a commercial agreement that will
  /// grow (delivery windows, vehicle type) and must not need a schema change
  /// to do it. See `ShipmentSelection.encode`.
  TextColumn get fulfillmentJson => text().nullable()();

  TextColumn get createdAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}
