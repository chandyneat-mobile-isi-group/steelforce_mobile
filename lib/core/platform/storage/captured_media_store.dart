/// Platform-selected storage for media the user just captured or picked
/// (proof photos, drawing uploads).
///
/// Both sides expose:
/// - `Future<String> persistCapturedBytes(bytes, {sourcePath, fileName})`
/// - `Future<String> copyCapturedFile(sourcePath, {targetDirectory, fileName})`
/// - `Future<void> deleteAppMediaDirectory(subfolder)`
///
/// Mobile writes real files and returns filesystem paths. Web wraps bytes in a
/// session-lifetime `blob:` URL and writes nothing to origin storage — see
/// `captured_media_store_web.dart` for why that is the correct behaviour under
/// ADR-010 rather than a missing feature.
library;

export 'captured_media_store_web.dart'
    if (dart.library.io) 'captured_media_store_native.dart';
