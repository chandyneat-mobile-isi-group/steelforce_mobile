/// Platform-neutral access to files the app previously wrote to local storage.
///
/// Replaces direct `dart:io` `File` use in presentation widgets and services.
/// Those call sites all followed the same two-step shape — "does this path
/// exist?" then "render/read it" — which is exactly what this exposes:
///
/// - `bool localFileExists(String path)`
/// - `Uint8List? readLocalFileSync(String path)`
/// - `Image localFileImage(String path, {fit, width, height})`
///
/// On Android/iOS these do the obvious thing. On web they report the file as
/// absent, which is the truth (a browser has no such path) and which every
/// call site already handles, since a local file can go missing on mobile too.
/// See `local_files_web.dart` for the full reasoning.
library;

export 'local_files_web.dart' if (dart.library.io) 'local_files_native.dart';
