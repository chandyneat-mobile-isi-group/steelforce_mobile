import 'package:steelforce/core/utils/enum_parse.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_collection.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_note.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_order_line.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_photo.dart';
import 'package:steelforce/features/my_visits/domain/entities/stock_level.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_return.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_stock_update.dart';

/// Row mapping for every small visit-capture entity — grouped in one file
/// since each is a handful of fields with an identical fromRow/toRow shape;
/// splitting them into six near-empty files wouldn't add clarity.

class VisitOrderLineModel extends VisitOrderLine {
  const VisitOrderLineModel({
    required super.id,
    required super.stopId,
    required super.productId,
    required super.productName,
    required super.quantity,
    required super.unit,
    required super.unitPrice,
  });

  factory VisitOrderLineModel.fromRow(DataMap row) => VisitOrderLineModel(
        id: row['id'] as String,
        stopId: row['stop_id'] as String,
        productId: row['product_id'] as String,
        productName: row['product_name'] as String,
        quantity: (row['quantity'] as num).toDouble(),
        unit: row['unit'] as String,
        unitPrice: (row['unit_price'] as num).toDouble(),
      );

  DataMap toRow() => {
        'id': id,
        'stop_id': stopId,
        'product_id': productId,
        'product_name': productName,
        'quantity': quantity,
        'unit': unit,
        'unit_price': unitPrice,
      };
}

class VisitStockUpdateModel extends VisitStockUpdate {
  const VisitStockUpdateModel({
    required super.id,
    super.stopId,
    super.depotId,
    required super.productId,
    required super.productName,
    required super.stockLevel,
    required super.notes,
  });

  factory VisitStockUpdateModel.fromRow(DataMap row) => VisitStockUpdateModel(
        id: row['id'] as String,
        stopId: row['stop_id'] as String?,
        depotId: row['depot_id'] as String?,
        productId: row['product_id'] as String,
        productName: row['product_name'] as String,
        stockLevel: StockLevel.parse(row['stock_level'] as String?),
        notes: row['notes'] as String,
      );

  DataMap toRow() => {
        'id': id,
        'stop_id': stopId,
        'depot_id': depotId,
        'product_id': productId,
        'product_name': productName,
        'stock_level': stockLevel.storageName,
        'notes': notes,
      };
}

/// SAP payload codes for [StockLevel] — the *only* place the app knows how a
/// three-tier status is spelled on the wire. UI and domain never see these;
/// the sync repository applies them when building the push payload for
/// `core/network/sap_client.dart` (mocked today).
extension StockLevelSapMapping on StockLevel {
  String get sapCode => switch (this) {
        StockLevel.low => 'LOW',
        StockLevel.medium => 'MED',
        StockLevel.high => 'HIGH',
      };

  static StockLevel fromSapCode(String code) => switch (code.toUpperCase()) {
        'MED' => StockLevel.medium,
        'HIGH' => StockLevel.high,
        _ => StockLevel.low,
      };
}

class VisitReturnModel extends VisitReturn {
  const VisitReturnModel({
    required super.id,
    required super.stopId,
    required super.productId,
    required super.productName,
    required super.quantity,
    required super.reason,
  });

  factory VisitReturnModel.fromRow(DataMap row) => VisitReturnModel(
        id: row['id'] as String,
        stopId: row['stop_id'] as String,
        productId: row['product_id'] as String,
        productName: row['product_name'] as String,
        quantity: (row['quantity'] as num).toDouble(),
        reason: row['reason'] as String,
      );

  DataMap toRow() => {
        'id': id,
        'stop_id': stopId,
        'product_id': productId,
        'product_name': productName,
        'quantity': quantity,
        'reason': reason,
      };
}

class VisitCollectionModel extends VisitCollection {
  const VisitCollectionModel({
    required super.id,
    required super.stopId,
    required super.amount,
    required super.method,
    required super.reference,
    required super.notes,
  });

  factory VisitCollectionModel.fromRow(DataMap row) => VisitCollectionModel(
        id: row['id'] as String,
        stopId: row['stop_id'] as String,
        amount: (row['amount'] as num).toDouble(),
        method: CollectionMethod.values.byNameOr(
            row['method'] as String?, CollectionMethod.values.first,
            context: 'capture.row.method'),
        reference: row['reference'] as String,
        notes: row['notes'] as String,
      );

  DataMap toRow() => {
        'id': id,
        'stop_id': stopId,
        'amount': amount,
        'method': method.name,
        'reference': reference,
        'notes': notes,
      };
}

class VisitNoteModel extends VisitNote {
  const VisitNoteModel({
    required super.id,
    required super.stopId,
    required super.type,
    required super.text,
    required super.createdAt,
  });

  factory VisitNoteModel.fromRow(DataMap row) => VisitNoteModel(
        id: row['id'] as String,
        stopId: row['stop_id'] as String,
        type: VisitNoteType.values.byNameOr(
            row['type'] as String?, VisitNoteType.values.first,
            context: 'note.row.type'),
        text: row['text'] as String,
        createdAt: DateTime.parse(row['created_at'] as String),
      );

  DataMap toRow() => {
        'id': id,
        'stop_id': stopId,
        'type': type.name,
        'text': text,
        'created_at': createdAt.toIso8601String(),
      };
}

class VisitPhotoModel extends VisitPhoto {
  const VisitPhotoModel({
    required super.id,
    required super.stopId,
    required super.url,
    required super.caption,
    required super.takenAt,
    super.isSignature,
  });

  factory VisitPhotoModel.fromRow(DataMap row) => VisitPhotoModel(
        id: row['id'] as String,
        stopId: row['stop_id'] as String,
        url: row['url'] as String,
        caption: row['caption'] as String,
        takenAt: DateTime.parse(row['taken_at'] as String),
        isSignature: (row['is_signature'] as int? ?? 0) == 1,
      );

  DataMap toRow() => {
        'id': id,
        'stop_id': stopId,
        'url': url,
        'caption': caption,
        'taken_at': takenAt.toIso8601String(),
        'is_signature': isSignature ? 1 : 0,
      };
}
