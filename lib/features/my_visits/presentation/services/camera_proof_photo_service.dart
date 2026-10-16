import 'package:steelforce/core/platform/storage/captured_media_store.dart';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:steelforce/core/camera/image_capture_service.dart';
import 'package:steelforce/features/my_visits/domain/services/proof_photo_service.dart';

/// Real camera-backed proof photo: captures via `image_picker` (which handles
/// the native camera permission prompt), then stamps the timestamp + GPS onto
/// the pixels on a background isolate (`compute`) so the UI thread never jank.
class CameraProofPhotoService implements ProofPhotoService {
  const CameraProofPhotoService(this._capture);

  /// The acquisition seam. Whether it is the device camera or the simulator
  /// stand-in is decided once, in the service locator — the stamping,
  /// persistence and result shape below are identical either way.
  final ImageCaptureService _capture;

  @override
  Future<ProofPhotoResult?> captureStamped(
      {required double latitude, required double longitude}) async {
    final XFile? shot = await _capture.capture(
      imageQuality: 70, // in-picker compression
      maxWidth: 1600,
    );
    if (shot == null) return null; // user backed out of the camera

    final takenAt = DateTime.now();
    final bytes = await shot.readAsBytes();

    final stamped = await compute(
      _stampImage,
      _StampRequest(
        bytes: bytes,
        lines: [
          _formatTimestamp(takenAt),
          'GPS ${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}',
        ],
      ),
    );

    // Mobile: persist alongside the picker's own file (a writable app cache
    // dir). Web: wrapped in a session-lifetime blob URL, since there is nowhere
    // to write — the stamp is still applied either way, because the stamping
    // above is pure Dart and runs on both platforms.
    final outPath = await persistCapturedBytes(
      stamped,
      sourcePath: shot.path,
      fileName: 'proof_${takenAt.microsecondsSinceEpoch}.jpg',
    );

    return ProofPhotoResult(filePath: outPath, takenAt: takenAt);
  }

  static String _formatTimestamp(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }
}

class _StampRequest {
  const _StampRequest({required this.bytes, required this.lines});
  final Uint8List bytes;
  final List<String> lines;
}

/// Runs inside a background isolate. Draws a translucent bar across the bottom
/// of the photo and writes the stamp lines onto it, then re-encodes as JPEG.
Uint8List _stampImage(_StampRequest req) {
  final decoded = img.decodeImage(req.bytes);
  if (decoded == null) return req.bytes;

  final font = img.arial24;
  const lineHeight = 30;
  const paddingX = 14;
  final barHeight = req.lines.length * lineHeight + 18;
  final top = decoded.height - barHeight;

  img.fillRect(
    decoded,
    x1: 0,
    y1: top,
    x2: decoded.width,
    y2: decoded.height,
    color: img.ColorRgba8(0, 0, 0, 140),
  );

  var y = top + 8;
  for (final line in req.lines) {
    img.drawString(decoded, line,
        font: font, x: paddingX, y: y, color: img.ColorRgb8(255, 255, 255));
    y += lineHeight;
  }

  return Uint8List.fromList(img.encodeJpg(decoded, quality: 80));
}
