import 'package:steelforce/core/platform/storage/captured_media_store.dart'
    as media;

/// Copies and deletes the photographs a queued registration holds. A seam so
/// tests need no filesystem; production uses `captured_media_store`.
class QueuedPhotoFiles {
  const QueuedPhotoFiles();

  /// Moves a captured file somewhere the OS will not clear before the replay.
  ///
  /// The picker writes to a cache directory that iOS and Android may empty at
  /// any time, and a queued registration can wait hours for a connection. On
  /// web there is no directory and the `blob:` reference is returned as-is —
  /// it lives as long as the tab (ADR-010).
  Future<String> keep(String sourcePath, {required String fileName}) async {
    final dir = await media.appMediaDirectory(_folder);
    if (dir == null) return sourcePath;
    return media.copyCapturedFile(
      sourcePath,
      targetDirectory: dir,
      fileName: fileName,
    );
  }

  void delete(String path) => media.deleteCapturedFile(path);

  static const _folder = 'depot_registration_queue';
}
