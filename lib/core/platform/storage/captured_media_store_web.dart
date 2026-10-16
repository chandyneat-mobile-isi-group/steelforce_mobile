import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:steelforce/core/platform/storage/web_media_registry.dart';

/// Web: there is no writable directory, so captured media is wrapped in an
/// in-memory blob and identified by its `blob:` URL.
///
/// The URL is valid for the lifetime of the tab, which matches ADR-010's
/// session-scoped posture exactly: the image is fully usable while the rep is
/// working, and it does not survive a reload. Nothing lands in origin storage,
/// so a photo of a depot's premises is not left behind in the browser.
///
/// The returned string is still "a path" as far as callers are concerned, which
/// is what lets `ProofPhotoResult` and the drawing-upload flow stay unchanged.
/// Its bytes are recorded in [WebMediaRegistry] at the same time, so
/// `local_files_web.dart` can show and read it for the rest of the session.
Future<String> persistCapturedBytes(
  Uint8List bytes, {
  required String sourcePath,
  required String fileName,
}) async {
  final path =
      XFile.fromData(bytes, name: fileName, mimeType: 'image/jpeg').path;
  WebMediaRegistry.put(path, bytes);
  return path;
}

/// Records a freshly picked image's bytes so it can be drawn and read back by
/// path for the rest of the session.
///
/// Every web caller skips [copyCapturedFile] (there is no directory to copy
/// into), so acquisition is the one moment every picked image passes through.
/// A file that cannot be read is skipped: the flow carries on and the image
/// shows its placeholder, as a missing file would on mobile.
Future<void> retainCapturedFile(XFile file) async {
  if (WebMediaRegistry.contains(file.path)) return;
  try {
    WebMediaRegistry.put(file.path, await file.readAsBytes());
  } catch (_) {}
}

/// Web has no directories to copy between, and the source is already a blob URL
/// that stays valid for the session — so the "copy into app storage" step is a
/// no-op that returns the original reference.
Future<String> copyCapturedFile(
  String sourcePath, {
  required String targetDirectory,
  required String fileName,
}) async {
  return sourcePath;
}

/// Web has no app-private directory. Returning null is the signal callers use
/// to skip the "copy into app storage" step entirely and keep using the blob
/// URL they already hold.
Future<String?> appMediaDirectory(String subfolder) async => null;

/// Web: nothing was written to disk; dropping the recorded bytes is the
/// delete. The blob itself is released when the tab drops its last reference.
void deleteCapturedFile(String path) => WebMediaRegistry.remove(path);

/// Web keeps no app-private directory, so there is nothing to delete.
Future<void> deleteAppMediaDirectory(String subfolder) async {}
