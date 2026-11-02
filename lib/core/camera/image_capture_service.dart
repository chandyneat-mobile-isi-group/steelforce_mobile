import 'package:image_picker/image_picker.dart';

/// Where an image came from, in the app's own vocabulary.
///
/// Deliberately not `ImageSource` from `image_picker`: that type belongs to the
/// real implementation, and a feature that names it is a feature that has
/// picked a side.
enum ImageCaptureSource { camera, gallery }

/// The one seam between a feature that wants a photograph and the hardware
/// that takes one.
///
/// ## Why this returns [XFile]
///
/// Because everything downstream already speaks it — the proof-photo stamper
/// reads bytes off it, the drawing upload copies its path, the depot
/// evidence upload posts it as a multipart file. Returning anything else would
/// force every one of those flows to branch on where the image came from,
/// which is exactly what this exists to prevent.
///
/// A mock image is written to a real file before it is returned, so a caller
/// doing `File(result.path)` cannot tell the difference.
///
/// ## What this is not
///
/// Not a replacement for [ProofPhotoService], [ImageSearchService] or the
/// depot evidence upload. Those own the *business* logic — stamping,
/// matching, compression, validation, upload — and keep it whether the pixels
/// came from a lens or an asset. This replaces only the acquisition step.
abstract interface class ImageCaptureService {
  /// Opens the camera (or its stand-in) and returns the captured image, or
  /// null when the user backed out.
  ///
  /// [maxWidth] and [imageQuality] are honoured by both implementations so a
  /// caller's compression intent survives the swap.
  Future<XFile?> capture({
    int? maxWidth,
    int? maxHeight,
    int? imageQuality,
    bool preferRearCamera = true,
  });

  /// Opens the photo library (or its stand-in).
  Future<XFile?> pickFromGallery({
    int? maxWidth,
    int? maxHeight,
    int? imageQuality,
  });

  /// Convenience for callers that already hold an [ImageCaptureSource].
  Future<XFile?> pick(
    ImageCaptureSource source, {
    int? maxWidth,
    int? maxHeight,
    int? imageQuality,
  });

  /// False when no image can be acquired at all — neither hardware nor
  /// stand-in. Features use it to hide a capture affordance rather than to
  /// branch on the platform.
  bool get isAvailable;

  /// True when images come from bundled test assets rather than a lens.
  ///
  /// **For a developer indicator only.** No business logic may branch on it:
  /// a mock image must travel the same processing, validation and upload path
  /// as a real one.
  bool get isMock;
}
