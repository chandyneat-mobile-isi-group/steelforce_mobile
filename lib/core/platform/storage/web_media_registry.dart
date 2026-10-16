import 'dart:typed_data';

/// The bytes of every image captured or copied in this browser tab, keyed by
/// the `blob:` path the rest of the app holds.
///
/// Web has no filesystem (ADR-010), but the photo flows are written against
/// paths: they store one, then later ask whether it exists, read it, or draw
/// it. A `blob:` URL cannot be read synchronously, so the web store records
/// the bytes here at the moment it hands a path out, and `local_files_web.dart`
/// answers from this map. A path is "present" only if it was registered in
/// this tab — a `blob:` path persisted by an earlier session is dead, and is
/// reported as missing so its screen takes the existing placeholder branch.
///
/// Web-only in effect: only the `_web` storage implementations touch it.
abstract final class WebMediaRegistry {
  static final Map<String, Uint8List> _bytes = {};

  static void put(String path, Uint8List bytes) => _bytes[path] = bytes;

  static Uint8List? get(String path) => _bytes[path];

  static bool contains(String path) => _bytes.containsKey(path);

  static void remove(String path) => _bytes.remove(path);
}
