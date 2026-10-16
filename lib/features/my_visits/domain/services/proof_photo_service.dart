/// Result of capturing a stamped proof-of-presence photo.
class ProofPhotoResult {
  const ProofPhotoResult({required this.filePath, required this.takenAt});

  /// Local file path of the compressed, GPS+timestamp-stamped JPEG.
  final String filePath;
  final DateTime takenAt;
}

/// Captures the shopfront proof photo at check-in and burns the time + GPS
/// coordinates onto the image so the back office has tamper-evident evidence
/// the visit really happened. UI-free (like the barcode/voice services) so the
/// camera + image plumbing stays out of the domain and blocs.
abstract interface class ProofPhotoService {
  /// Opens the camera, compresses the shot, and stamps [latitude]/[longitude]
  /// + the capture time onto it. Resolves with the saved file, or `null` if
  /// the user cancelled.
  Future<ProofPhotoResult?> captureStamped(
      {required double latitude, required double longitude});
}
