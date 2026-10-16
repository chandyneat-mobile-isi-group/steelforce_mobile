/// Platform-selected document store backing [PdfFileService].
///
/// Same mechanism as `connection/database_connection.dart`: the native side
/// imports `dart:io` and `path_provider`, neither of which exists on web, so
/// the compiler picks the implementation.
///
/// Both sides expose `Future<SavedDocument> storePdfBytes(Uint8List bytes,`
/// `String fileName)`. Mobile writes into the app sandbox; web keeps the bytes
/// in memory and stores nothing (see `pdf_file_store_web.dart` for why).
library;

export 'pdf_file_store_web.dart'
    if (dart.library.io) 'pdf_file_store_native.dart';
