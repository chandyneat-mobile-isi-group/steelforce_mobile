import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:steelforce/core/platform/storage/web_media_registry.dart';

/// Web implementations. Selected by the conditional export in
/// `local_files.dart` — never compiled on Android/iOS.
///
/// A browser has no filesystem, so a "path" here is the `blob:` reference the
/// web capture store handed out, and its bytes live in [WebMediaRegistry] for
/// the life of the tab. An image captured in this session is therefore shown
/// and read like a file on mobile.
///
/// Anything else — a `blob:` path persisted by an earlier session, or a mobile
/// path in synced data — is reported absent. Every call site already handles
/// a missing file with a placeholder, because a file can legitimately
/// disappear on mobile too (cache eviction, user cleanup).

bool localFileExists(String path) => WebMediaRegistry.contains(path);

Uint8List? readLocalFileSync(String path) => WebMediaRegistry.get(path);

Image localFileImage(
  String path, {
  BoxFit? fit,
  double? width,
  double? height,
}) {
  return Image.memory(
    WebMediaRegistry.get(path) ?? Uint8List(0),
    fit: fit,
    width: width,
    height: height,
    errorBuilder: (_, __, ___) => SizedBox(width: width, height: height),
  );
}
