import 'dart:io';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:path_provider/path_provider.dart';

/// Android/iOS: write [bytes] next to the file the picker produced, which is
/// already a writable app-owned cache directory. Selected by the conditional
/// export in `captured_media_store.dart`.
Future<String> persistCapturedBytes(
  Uint8List bytes, {
  required String sourcePath,
  required String fileName,
}) async {
  final dir = File(sourcePath).parent.path;
  final outPath = '$dir/$fileName';
  await File(outPath).writeAsBytes(bytes, flush: true);
  return outPath;
}

/// Returns (creating if needed) a [subfolder] inside the app's private
/// documents directory — the sandboxed location `SECURITY.md` §3 requires for
/// depot-derived media.
Future<String?> appMediaDirectory(String subfolder) async {
  final appDir = await getApplicationDocumentsDirectory();
  return '${appDir.path}${Platform.pathSeparator}$subfolder';
}

/// Native: a picked image is already a real file on disk, so there is
/// nothing to retain. Exists for the web store, which must record the bytes.
Future<void> retainCapturedFile(XFile file) async {}

/// Copies [sourcePath] to [targetDirectory]/[fileName] and returns the new path.
Future<String> copyCapturedFile(
  String sourcePath, {
  required String targetDirectory,
  required String fileName,
}) async {
  final dir = Directory(targetDirectory);
  if (!await dir.exists()) await dir.create(recursive: true);
  final target = '$targetDirectory/$fileName';
  await File(sourcePath).copy(target);
  return target;
}

/// Best-effort delete of a previously captured file. Silent on failure —
/// a stale cache file is not worth surfacing to a sales rep.
void deleteCapturedFile(String path) {
  try {
    final file = File(path);
    if (file.existsSync()) file.deleteSync();
  } catch (_) {}
}

/// Deletes [subfolder] of the app's private documents directory and
/// everything in it. A no-op when it does not exist.
Future<void> deleteAppMediaDirectory(String subfolder) async {
  final appDir = await getApplicationDocumentsDirectory();
  final dir = Directory('${appDir.path}${Platform.pathSeparator}$subfolder');
  if (await dir.exists()) await dir.delete(recursive: true);
}
