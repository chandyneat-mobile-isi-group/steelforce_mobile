import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image_picker/image_picker.dart';
import 'package:steelforce/core/camera/camera_mode.dart';
import 'package:steelforce/core/camera/image_capture_service.dart';
import 'package:steelforce/core/camera/mock/mock_camera_asset.dart';
import 'package:steelforce/core/camera/mock/mock_camera_screen.dart';
import 'package:steelforce/core/logging/debug_trace.dart';
import 'package:steelforce/core/platform/storage/captured_media_store.dart';

const _trace = DebugTrace('camera');

/// Raised when a bundled test image cannot be read.
///
/// Surfaced rather than swallowed: a missing asset means `pubspec.yaml` and the
/// asset folder have drifted apart, and silently returning null would look
/// exactly like a developer cancelling the camera.
class MockCameraAssetException implements Exception {
  const MockCameraAssetException(this.assetPath, this.cause);
  final String assetPath;
  final Object cause;

  @override
  String toString() =>
      'MockCameraAssetException: could not load $assetPath — $cause. '
      'Check that "${MockCameraAsset.directory}/" is listed under assets in '
      'pubspec.yaml (Flutter does not recurse into subdirectories).';
}

/// The stand-in camera: bundled test images, returned as real files.
///
/// ## Why this exists
///
/// The iOS Simulator has no camera. `image_picker` opens and returns nothing,
/// so every flow that needs a photograph — depot evidence, visit proof,
/// drawing upload, visual search — is untestable there. This returns a real
/// image through the same type, so those flows run unchanged.
///
/// ## Why it writes a file
///
/// Callers do `File(result.path)`, read bytes off it, copy it, post it as
/// multipart. Handing back an in-memory object would force each of them to
/// learn where the image came from, which is the coupling this whole seam
/// exists to remove. The bytes are written through
/// [persistCapturedBytes], the same store the real capture paths already use,
/// so mobile gets a filesystem path and web gets a blob URL.
class MockImageCaptureService implements ImageCaptureService {
  MockImageCaptureService({
    required GlobalKey<NavigatorState> navigatorKey,
    AssetBundle? bundle,
  })  : _navigatorKey = navigatorKey,
        _bundle = bundle ?? rootBundle;

  /// Used to push the picker over whatever is on screen — the same trick
  /// `MobileBarcodeScannerService` and `SpeechVoiceSearchService` use, so the
  /// caller never has to hand in a `BuildContext`.
  final GlobalKey<NavigatorState> _navigatorKey;

  final AssetBundle _bundle;

  @override
  bool get isAvailable => true;

  @override
  bool get isMock => true;

  @override
  Future<XFile?> capture({
    int? maxWidth,
    int? maxHeight,
    int? imageQuality,
    bool preferRearCamera = true,
  }) =>
      // Sizing hints are accepted and ignored: the bundled assets are already
      // small, and re-encoding them would only add a decode step to a
      // developer-only path.
      _run(ImageCaptureSource.camera);

  @override
  Future<XFile?> pickFromGallery(
          {int? maxWidth, int? maxHeight, int? imageQuality}) =>
      _run(ImageCaptureSource.gallery);

  /// The stand-in picks one image per visit to its screen; that is enough
  /// to exercise a multi-select caller.
  @override
  Future<List<XFile>> pickMultipleFromGallery({
    int? maxWidth,
    int? maxHeight,
    int? imageQuality,
    int? limit,
  }) async {
    final file = await _run(ImageCaptureSource.gallery);
    return file == null ? const [] : [file];
  }

  @override
  Future<XFile?> pick(
    ImageCaptureSource source, {
    int? maxWidth,
    int? maxHeight,
    int? imageQuality,
  }) =>
      _run(source);

  Future<XFile?> _run(ImageCaptureSource source) async {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) {
      // No navigator yet — the app is mid-boot. Falling back to the default
      // asset keeps a caller working rather than failing for a reason that has
      // nothing to do with it.
      _trace.warn('mock', 'no navigator; using default asset',
          {'asset': MockCameraAsset.fallback.fileName});
      return resolveAsset(MockCameraAsset.fallback);
    }

    _trace.step('mock', 'picker opened', {'source': source.name});
    final chosen = await navigator.push<MockCameraAsset>(
      MaterialPageRoute<MockCameraAsset>(
        fullscreenDialog: true,
        builder: (_) => MockCameraScreen(source: source),
      ),
    );

    if (chosen == null) {
      // Backed out. Null is exactly what the real picker returns, so every
      // caller's existing cancel path already handles it.
      _trace.step('mock', 'cancelled');
      return null;
    }
    return resolveAsset(chosen);
  }

  /// Loads [asset] and writes it to a real file.
  ///
  /// Public so a test can exercise the asset path without a navigator.
  Future<XFile> resolveAsset(MockCameraAsset asset) async {
    final Uint8List bytes;
    try {
      final data = await _bundle.load(asset.assetPath);
      bytes = data.buffer.asUint8List();
    } on Object catch (error) {
      _trace.fail('mock', 'asset load failed', {'asset': asset.fileName});
      throw MockCameraAssetException(asset.assetPath, error);
    }

    if (bytes.isEmpty) {
      throw MockCameraAssetException(asset.assetPath, 'the asset was empty');
    }

    // `persistCapturedBytes` writes beside a source file, and a bundled asset
    // has none. `appMediaDirectory` yields `<documents>/mock_camera` on mobile
    // and null on web; passing it as the anchor puts the file in
    // `<documents>/`, a directory that already exists, and web ignores the
    // anchor entirely and answers with a blob URL.
    final anchor = await appMediaDirectory('mock_camera');
    final fileName =
        'mock_${asset.name}_${DateTime.now().microsecondsSinceEpoch}.png';

    final path = await persistCapturedBytes(
      bytes,
      sourcePath: anchor ?? fileName,
      fileName: fileName,
    );

    _trace.ok('mock', 'image returned',
        {'asset': asset.fileName, 'bytes': bytes.length});
    return XFile(path);
  }
}

/// Whether the running build is using the stand-in camera.
///
/// For developer indicators only — never branch business logic on it.
bool get isMockCameraActive => CameraConfig.useMock;
