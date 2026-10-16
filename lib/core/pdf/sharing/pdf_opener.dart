/// Platform-selected "open this file in the OS viewer" hook.
///
/// Exists to keep `open_filex`, which publishes no web implementation, out of
/// the web compile. Both sides expose
/// `Future<void> openDocumentAtPath(String path)`.
library;

export 'pdf_opener_web.dart' if (dart.library.io) 'pdf_opener_native.dart';
