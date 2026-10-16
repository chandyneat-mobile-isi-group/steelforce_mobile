import 'package:image_picker/image_picker.dart';
import 'package:steelforce/core/camera/image_capture_service.dart';
import 'package:steelforce/features/order/domain/services/image_search_service.dart';

/// Real `image_picker`-backed implementation of visual product search.
///
/// The picker handles the native camera/photo-library permission prompts
/// itself. Turning the photo into matched SKUs is the job of a multi-modal
/// embedding endpoint in production; there's no such backend in this offline
/// demo, so [_mockMatch] deterministically maps the picked file onto a real
/// catalog keyword — enough to return genuine product cards and exercise the
/// whole flow end to end.
class ImagePickerSearchService implements ImageSearchService {
  const ImagePickerSearchService(this._capture);

  /// The acquisition seam — real camera on a device, bundled test image on the
  /// simulator. The keyword matching below is unchanged either way.
  final ImageCaptureService _capture;

  static const List<String> _catalogKeywords = [
    'Rebar',
    'Wire Rod',
    'H Beam',
    'I Beam',
    'C Channel',
    'Angle Bar',
    'Steel Plate',
    'Steel Sheet',
    'GI Pipe',
    'Black Pipe',
    'Stainless Pipe',
    'Hex Bolt',
    'Hex Nut',
    'Cement',
  ];

  @override
  Future<String?> matchQuery(ImageSearchSource source) async {
    final XFile? file = await _capture.pick(
      source == ImageSearchSource.camera
          ? ImageCaptureSource.camera
          : ImageCaptureSource.gallery,
      imageQuality: 70,
      maxWidth: 1280,
    );
    if (file == null) return null; // user cancelled
    return _mockMatch(file);
  }

  /// Stand-in for the visual-embedding lookup: deterministic so the same photo
  /// always resolves to the same product family, non-negative index guaranteed.
  String _mockMatch(XFile file) {
    final index = file.name.hashCode.abs() % _catalogKeywords.length;
    return _catalogKeywords[index];
  }
}
