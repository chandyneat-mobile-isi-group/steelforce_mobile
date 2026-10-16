import 'package:equatable/equatable.dart';
import 'package:steelforce/features/my_visits/domain/entities/stock_level.dart';

enum DepotStockCountStatus {
  initial,
  loading,

  /// Local catalog was empty on open, so we're pulling it once from sync
  /// before showing products. Rendered as a loading state (never blank).
  syncing,
  loaded,
  empty,
  error,
  saving,
  saved,
}

/// One SKU whose stock status is being set at the selected depot/shop.
class StockCountLine extends Equatable {
  const StockCountLine({
    required this.productId,
    required this.name,
    required this.subtitle,
    this.imageUrl = '',
    this.size = '',
    this.level,
  });

  final String productId;
  final String name;
  final String subtitle;
  final String imageUrl;
  final String size;

  /// The selected three-tier status; `null` until the rep picks one.
  final StockLevel? level;

  bool get isSet => level != null;

  StockCountLine copyWith({StockLevel? level}) => StockCountLine(
        productId: productId,
        name: name,
        subtitle: subtitle,
        imageUrl: imageUrl,
        size: size,
        level: level ?? this.level,
      );

  @override
  List<Object?> get props => [productId, name, subtitle, imageUrl, size, level];
}

class DepotStockCountState extends Equatable {
  const DepotStockCountState({
    this.status = DepotStockCountStatus.initial,
    this.shopName,
    this.lines = const [],
    this.message,
    this.showValidation = false,
  });

  final DepotStockCountStatus status;
  final String? shopName;
  final List<StockCountLine> lines;
  final String? message;

  /// True once the rep tried to finish with unset lines — rows without a
  /// status highlight themselves until every product has one.
  final bool showValidation;

  int get setCount => lines.where((l) => l.isSet).length;
  bool get isComplete => lines.isNotEmpty && lines.every((l) => l.isSet);

  DepotStockCountState copyWith({
    DepotStockCountStatus? status,
    String? shopName,
    List<StockCountLine>? lines,
    String? message,
    bool? showValidation,
  }) {
    return DepotStockCountState(
      status: status ?? this.status,
      shopName: shopName ?? this.shopName,
      lines: lines ?? this.lines,
      message: message ?? this.message,
      showValidation: showValidation ?? this.showValidation,
    );
  }

  @override
  List<Object?> get props => [status, shopName, lines, message, showValidation];
}
