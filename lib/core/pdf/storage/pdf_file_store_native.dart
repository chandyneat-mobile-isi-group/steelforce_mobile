import 'dart:io';
import 'dart:typed_data';

import 'package:steelforce/core/pdf/storage/saved_document.dart';
import 'package:path_provider/path_provider.dart';

/// Android/iOS document store. Selected by the conditional export in
/// `pdf_file_store.dart` — never compiled on web.
///
/// Security (`SECURITY.md` §3/§10): documents contain depot data and pricing,
/// so they are written **only** inside the app sandbox
/// ([getApplicationDocumentsDirectory] — never a public/cache/Downloads folder),
/// under a dedicated `pdf/` subfolder.
Future<SavedDocument> storePdfBytes(Uint8List bytes, String fileName) async {
  final docsDir = await getApplicationDocumentsDirectory();
  final pdfDir = Directory('${docsDir.path}${Platform.pathSeparator}pdf');
  if (!await pdfDir.exists()) {
    await pdfDir.create(recursive: true);
  }

  final file = File('${pdfDir.path}${Platform.pathSeparator}$fileName');
  await file.writeAsBytes(bytes, flush: true);
  return SavedDocument(fileName: fileName, bytes: bytes, path: file.path);
}
