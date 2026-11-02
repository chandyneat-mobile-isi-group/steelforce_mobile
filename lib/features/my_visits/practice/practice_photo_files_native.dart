import 'dart:io';

/// Best-effort: a practice photo that cannot be deleted is not worth failing
/// the end of a lesson over.
Future<void> deletePracticePhotoFile(String path) async {
  try {
    final file = File(path);
    if (await file.exists()) await file.delete();
  } catch (_) {}
}
