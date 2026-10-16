import 'package:image_picker/image_picker.dart';
import 'package:steelforce/core/camera/image_capture_service.dart';

/// The device camera and photo library, via `image_picker`.
///
/// A thin pass-through on purpose. `image_picker` already handles the native
/// permission prompts, the cancel path (a null result) and in-picker
/// downscaling, so wrapping it in anything more would be re-implementing a
/// plugin to no end.
class RealImageCaptureService implements ImageCaptureService {
  /// [picker] is injectable so a test can drive this without a platform
  /// channel — the same shape `CustomizationCubit` already uses.
  RealImageCaptureService({ImagePicker? picker})
      : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  bool get isAvailable => true;

  @override
  bool get isMock => false;

  @override
  Future<XFile?> capture({
    int? maxWidth,
    int? maxHeight,
    int? imageQuality,
    bool preferRearCamera = true,
  }) =>
      _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: maxWidth?.toDouble(),
        maxHeight: maxHeight?.toDouble(),
        imageQuality: imageQuality,
        preferredCameraDevice:
            preferRearCamera ? CameraDevice.rear : CameraDevice.front,
      );

  @override
  Future<XFile?> pickFromGallery(
          {int? maxWidth, int? maxHeight, int? imageQuality}) =>
      _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: maxWidth?.toDouble(),
        maxHeight: maxHeight?.toDouble(),
        imageQuality: imageQuality,
      );

  @override
  Future<List<XFile>> pickMultipleFromGallery({
    int? maxWidth,
    int? maxHeight,
    int? imageQuality,
    int? limit,
  }) =>
      _picker.pickMultiImage(
        maxWidth: maxWidth?.toDouble(),
        maxHeight: maxHeight?.toDouble(),
        imageQuality: imageQuality,
        limit: limit,
      );

  @override
  Future<XFile?> pick(
    ImageCaptureSource source, {
    int? maxWidth,
    int? maxHeight,
    int? imageQuality,
  }) =>
      source == ImageCaptureSource.camera
          ? capture(
              maxWidth: maxWidth,
              maxHeight: maxHeight,
              imageQuality: imageQuality)
          : pickFromGallery(
              maxWidth: maxWidth,
              maxHeight: maxHeight,
              imageQuality: imageQuality);
}
