import 'package:equatable/equatable.dart';
import 'package:steelforce/features/order/domain/entities/data_domain.dart';

sealed class CustomizationState extends Equatable {
  const CustomizationState();

  @override
  List<Object?> get props => [];
}

final class CustomizationInitial extends CustomizationState {
  const CustomizationInitial();
}

final class CustomizationLoading extends CustomizationState {
  final String statusMessage;
  const CustomizationLoading({this.statusMessage = 'Processing image...'});

  @override
  List<Object?> get props => [statusMessage];
}

final class CustomizationDataState extends CustomizationState {
  final String? drawingImagePath;
  final CustomizationMeasurement measurements;
  final String notes;
  final String appearance;
  final String selectedUnit;
  final double quantity;

  const CustomizationDataState({
    this.drawingImagePath,
    this.measurements = const CustomizationMeasurement(),
    this.notes = '',
    this.appearance = '',
    this.selectedUnit = 'Pc',
    this.quantity = 1.0,
  });

  CustomizationDataState copyWith({
    Object? drawingImagePath = _undefined,
    CustomizationMeasurement? measurements,
    String? notes,
    String? appearance,
    String? selectedUnit,
    double? quantity,
  }) {
    return CustomizationDataState(
      drawingImagePath: drawingImagePath == _undefined
          ? this.drawingImagePath
          : drawingImagePath as String?,
      measurements: measurements ?? this.measurements,
      notes: notes ?? this.notes,
      appearance: appearance ?? this.appearance,
      selectedUnit: selectedUnit ?? this.selectedUnit,
      quantity: quantity ?? this.quantity,
    );
  }

  @override
  List<Object?> get props => [
        drawingImagePath,
        measurements,
        notes,
        appearance,
        selectedUnit,
        quantity,
      ];
}

const Object _undefined = Object();

final class CustomizationError extends CustomizationState {
  final String message;
  const CustomizationError(this.message);

  @override
  List<Object?> get props => [message];
}
