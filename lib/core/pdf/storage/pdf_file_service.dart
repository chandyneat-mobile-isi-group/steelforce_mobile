import 'dart:typed_data';

import 'package:steelforce/core/pdf/storage/pdf_file_store.dart';
import 'package:steelforce/core/pdf/storage/saved_document.dart';

/// Persists generated PDF bytes using whatever storage the platform allows.
///
/// Where the bytes actually go is the platform store's decision
/// (`pdf_file_store.dart`): the app sandbox on Android/iOS, nowhere at all on
/// web. What this class owns is the part that must be identical everywhere —
/// filename construction.
///
/// Filenames are sanitized and stamped to the second, which both prevents
/// path-injection via a caller-supplied prefix and guarantees a new file per
/// export (no silent overwrite of a prior quotation). The sanitizing matters on
/// web too, even without a filesystem: the name becomes the browser's suggested
/// download filename.
abstract class PdfFileService {
  /// Saves [bytes] and returns the resulting [SavedDocument]. [fileNamePrefix]
  /// is sanitized; a `_YYYYMMDD_HHmmss.pdf` suffix is always appended.
  ///
  /// Check [SavedDocument.isOnDisk] before telling the user the document was
  /// saved — on web nothing is written until they accept a download.
  Future<SavedDocument> save(Uint8List bytes, {required String fileNamePrefix});
}

class PdfFileServiceImpl implements PdfFileService {
  const PdfFileServiceImpl();

  static final RegExp _unsafe = RegExp(r'[^A-Za-z0-9_-]');

  @override
  Future<SavedDocument> save(
    Uint8List bytes, {
    required String fileNamePrefix,
  }) {
    return storePdfBytes(bytes, _buildFileName(fileNamePrefix));
  }

  String _buildFileName(String prefix) {
    final safePrefix = prefix.replaceAll(_unsafe, '_');
    final effectivePrefix = safePrefix.isEmpty ? 'ISI_Document' : safePrefix;
    return '${effectivePrefix}_${_timestamp()}.pdf';
  }

  String _timestamp() {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}'
        '_${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }
}
