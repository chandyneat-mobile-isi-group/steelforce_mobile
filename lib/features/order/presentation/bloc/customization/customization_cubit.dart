import 'package:steelforce/core/platform/storage/captured_media_store.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:steelforce/core/camera/image_capture_service.dart';

import 'package:steelforce/features/order/domain/entities/data_domain.dart';
import 'package:steelforce/features/order/presentation/bloc/customization/customization_state.dart';

class CustomizationCubit extends Cubit<CustomizationState> {
  /// The acquisition seam. Previously an `ImagePicker` constructed here, which
  /// meant the drawing upload could not be exercised on the simulator at all.
  final ImageCaptureService _capture;

  CustomizationCubit({required ImageCaptureService capture})
      : _capture = capture,
        super(const CustomizationDataState());

  CustomizationDataState get _currentState => state is CustomizationDataState
      ? (state as CustomizationDataState)
      : const CustomizationDataState();

  Future<void> captureOrPickDrawing(ImageCaptureSource source) async {
    final previous = _currentState;
    try {
      emit(const CustomizationLoading());
      // image_picker requests the camera/photo permission itself and downscales
      // the capture via [imageQuality]/[maxWidth]/[maxHeight], so no separate
      // permission or compression package is needed.
      final XFile? file = await _capture.pick(
        source,
        imageQuality: 75,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (file == null) {
        emit(previous);
        return;
      }

      final storedPath = await _storeDrawing(file.path);
      if (storedPath != null) {
        emit(previous.copyWith(drawingImagePath: storedPath));
      } else {
        emit(const CustomizationError('Failed to save drawing file.'));
      }
    } catch (e) {
      emit(CustomizationError('Error capturing drawing: ${e.toString()}'));
    }
  }

  void removeDrawing() {
    final path = _currentState.drawingImagePath;
    if (path != null) deleteCapturedFile(path);
    emit(_currentState.copyWith(drawingImagePath: null));
  }

  void updateMeasurements({
    double? lengthMm,
    double? widthMm,
    double? heightMm,
    double? thicknessMm,
    double? diameterMm,
  }) {
    final current = _currentState.measurements;
    final updated = CustomizationMeasurement(
      lengthMm: lengthMm ?? current.lengthMm,
      widthMm: widthMm ?? current.widthMm,
      heightMm: heightMm ?? current.heightMm,
      thicknessMm: thicknessMm ?? current.thicknessMm,
      diameterMm: diameterMm ?? current.diameterMm,
    );
    emit(_currentState.copyWith(measurements: updated));
  }

  /// Seeds the measurements once (used to prefill the form from the base
  /// product's spec without marking every field dirty).
  void seedMeasurements(CustomizationMeasurement measurements) {
    emit(_currentState.copyWith(measurements: measurements));
  }

  void updateNotes(String notes) {
    emit(_currentState.copyWith(notes: notes));
  }

  void updateAppearance(String appearance) {
    emit(_currentState.copyWith(appearance: appearance));
  }

  void updateUnit(String unit) {
    emit(_currentState.copyWith(selectedUnit: unit));
  }

  void updateQuantity(double qty) {
    emit(_currentState.copyWith(quantity: qty));
  }

  /// Copies the picked (already-downscaled) image into the app's private
  /// `drawing_cache` directory so it survives the temp file being reclaimed.
  Future<String?> _storeDrawing(String rawPath) async {
    try {
      final targetFolder = await appMediaDirectory('drawing_cache');

      // Web: no app-private directory to copy into. `rawPath` is already a
      // blob URL that stays valid for the tab's lifetime, which is the right
      // scope under ADR-010 — returning it keeps the drawing usable for this
      // session without persisting depot artwork into browser storage.
      if (targetFolder == null) return rawPath;

      return await copyCapturedFile(
        rawPath,
        targetDirectory: targetFolder,
        fileName: 'drawing_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
    } catch (_) {
      return null;
    }
  }
}
