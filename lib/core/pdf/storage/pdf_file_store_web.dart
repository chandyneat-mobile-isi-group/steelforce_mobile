import 'dart:typed_data';

import 'package:steelforce/core/pdf/storage/saved_document.dart';

/// Web document store. Selected by the conditional export in
/// `pdf_file_store.dart` — never compiled on Android/iOS.
///
/// Writes nothing. A browser tab has no sandbox directory it may write a file
/// into, and the two places it *could* put bytes — IndexedDB or OPFS — are
/// exactly the unencrypted origin-readable storage ADR-010 keeps depot data
/// out of. A quotation PDF carries depot names, addresses, and pricing, so
/// persisting one in the browser would reintroduce the problem ADR-010 avoids
/// for the database, in a different file.
///
/// So on web a document lives in memory until the user acts on it, and
/// `PdfShareService` turns that action into a browser download or print. The
/// returned [SavedDocument] reports `isOnDisk == false`, which is what callers
/// check before telling the user anything was saved.
Future<SavedDocument> storePdfBytes(Uint8List bytes, String fileName) async {
  return SavedDocument(fileName: fileName, bytes: bytes);
}
