import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';

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
/// What it is *not* is a filesystem path — `localFileExists` reports false for
/// it, so screens that re-render a previously captured image fall back to their
/// existing placeholder rather than showing a broken frame.
Future<String> persistCapturedBytes(
  Uint8List bytes, {
  required String sourcePath,
  required String fileName,
}) async {
  return XFile.fromData(bytes, name: fileName, mimeType: 'image/jpeg').path;
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

/// Web: nothing was written, so nothing needs deleting. The blob is released
/// when the tab drops its last reference.
void deleteCapturedFile(String path) {}

/// Web keeps no app-private directory, so there is nothing to delete.
Future<void> deleteAppMediaDirectory(String subfolder) async {}
