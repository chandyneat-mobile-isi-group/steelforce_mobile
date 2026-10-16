import 'dart:typed_data';

import 'package:flutter/widgets.dart';

/// Web implementations. Selected by the conditional export in
/// `local_files.dart` — never compiled on Android/iOS.
///
/// ## Why these report "nothing there" rather than throwing
///
/// Every caller of these functions is asking about a **filesystem path** that a
/// mobile build wrote earlier — a captured proof photo, an uploaded drawing.
/// A browser has no such path and no such file, so "absent" is the truthful
/// answer, not a failure.
///
/// It is also the answer the call sites already handle well: each one guards
/// with an existence check and renders a placeholder when the image is missing,
/// because a file can legitimately disappear on mobile too (cache eviction,
/// user cleanup). Web simply takes that existing branch every time, which is
/// why adapting these screens needed no new UI states.
///
/// This is the honest consequence of ADR-010: on web there is no durable local
/// media, so previously-captured local media cannot be shown. Newly picked
/// images still work in-session — `image_picker_for_web` hands back bytes, and
/// the flows that use bytes rather than paths are unaffected.

bool localFileExists(String path) => false;

Uint8List? readLocalFileSync(String path) => null;

/// Never reached: every call site is guarded by [localFileExists], which is
/// always false here. Kept total rather than throwing so that a future
/// unguarded caller degrades to an empty box instead of crashing a screen.
Image localFileImage(
  String path, {
  BoxFit? fit,
  double? width,
  double? height,
}) {
  return Image.memory(
    Uint8List(0),
    fit: fit,
    width: width,
    height: height,
    errorBuilder: (_, __, ___) => SizedBox(width: width, height: height),
  );
}
