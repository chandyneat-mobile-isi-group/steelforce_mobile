import 'package:equatable/equatable.dart';

// Export product.dart so everything importing data_domain.dart uses the unified Product class
export 'product.dart';

/// Represents specific custom measurements for tailored steel / manufacturing products.
///
/// All values are millimetres. A null value means "not specified for this
/// product's category" (see `ProductCustomizationSpec`), not zero.
class CustomizationMeasurement extends Equatable {
  final double? lengthMm;
  final double? widthMm;
  final double? heightMm;
  final double? thicknessMm;
  final double? diameterMm;

  const CustomizationMeasurement({
    this.lengthMm,
    this.widthMm,
    this.heightMm,
    this.thicknessMm,
    this.diameterMm,
  });

  bool get isEmpty =>
      (lengthMm == null || lengthMm == 0) &&
      (widthMm == null || widthMm == 0) &&
      (heightMm == null || heightMm == 0) &&
      (thicknessMm == null || thicknessMm == 0) &&
      (diameterMm == null || diameterMm == 0);

  CustomizationMeasurement copyWith({
    double? lengthMm,
    double? widthMm,
    double? heightMm,
    double? thicknessMm,
    double? diameterMm,
  }) {
    return CustomizationMeasurement(
      lengthMm: lengthMm ?? this.lengthMm,
      widthMm: widthMm ?? this.widthMm,
      heightMm: heightMm ?? this.heightMm,
      thicknessMm: thicknessMm ?? this.thicknessMm,
      diameterMm: diameterMm ?? this.diameterMm,
    );
  }

  String toSummaryString() {
    final parts = <String>[];
    if (lengthMm != null && lengthMm! > 0) {
      parts.add('L: ${lengthMm!.toStringAsFixed(0)}mm');
    }
    if (widthMm != null && widthMm! > 0) {
      parts.add('W: ${widthMm!.toStringAsFixed(0)}mm');
    }
    if (heightMm != null && heightMm! > 0) {
      parts.add('H: ${heightMm!.toStringAsFixed(0)}mm');
    }
    if (thicknessMm != null && thicknessMm! > 0) {
      parts.add('T: ${thicknessMm!.toStringAsFixed(1)}mm');
    }
    if (diameterMm != null && diameterMm! > 0) {
      parts.add('Ø: ${diameterMm!.toStringAsFixed(0)}mm');
    }
    return parts.isEmpty ? 'Custom Specs' : parts.join(' × ');
  }

  Map<String, dynamic> toJson() => {
        'lengthMm': lengthMm,
        'widthMm': widthMm,
        'heightMm': heightMm,
        'thicknessMm': thicknessMm,
        'diameterMm': diameterMm,
      };

  factory CustomizationMeasurement.fromJson(Map<String, dynamic> json) {
    return CustomizationMeasurement(
      lengthMm: (json['lengthMm'] as num?)?.toDouble(),
      widthMm: (json['widthMm'] as num?)?.toDouble(),
      heightMm: (json['heightMm'] as num?)?.toDouble(),
      thicknessMm: (json['thicknessMm'] as num?)?.toDouble(),
      diameterMm: (json['diameterMm'] as num?)?.toDouble(),
    );
  }

  @override
  List<Object?> get props =>
      [lengthMm, widthMm, heightMm, thicknessMm, diameterMm];
}
