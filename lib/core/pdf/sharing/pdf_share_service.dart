import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:steelforce/core/pdf/sharing/pdf_opener.dart';
import 'package:steelforce/core/pdf/storage/saved_document.dart';
import 'package:printing/printing.dart';

/// Presents a generated PDF to the user: on-device preview, native
/// print/share, or opening the saved document in an external viewer.
///
/// Fully offline — [Printing] operates on local bytes and makes no network
/// calls, which keeps the whole export flow airplane-mode safe (STEP 9). Kept
/// behind an interface so the UI/Cubit never touch the printing plugin directly
/// and so it can be faked in widget tests.
///
/// `printing` has a real web implementation, so preview/print/share work in a
/// browser unchanged. Only [openSaved] genuinely differs between platforms —
/// see its doc.
abstract class PdfShareService {
  /// Opens the OS print/preview sheet for [bytes]. On Android and iOS this same
  /// sheet exposes preview, print, and "Share/Save to Files"; in a browser it
  /// opens the print dialog, which also offers "Save as PDF". [documentName]
  /// labels the print job.
  Future<void> previewAndPrint(Uint8List bytes, {required String documentName});

  /// Opens the native share sheet with the PDF attached as [fileName]. On web
  /// this triggers a browser download.
  Future<void> share(Uint8List bytes, {required String fileName});

  /// Re-presents an already-generated [document].
  ///
  /// On mobile this hands the saved path to the platform's default PDF viewer.
  /// On web there is no saved path and no external viewer to hand it to, so the
  /// closest honest equivalent is to re-offer the same bytes as a download —
  /// which is also the only way the user can get the document out of the tab.
  Future<void> openSaved(SavedDocument document);
}

class PdfShareServiceImpl implements PdfShareService {
  const PdfShareServiceImpl();

  @override
  Future<void> previewAndPrint(
    Uint8List bytes, {
    required String documentName,
  }) {
    return Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: documentName,
    );
  }

  @override
  Future<void> share(Uint8List bytes, {required String fileName}) {
    return Printing.sharePdf(bytes: bytes, filename: fileName);
  }

  @override
  Future<void> openSaved(SavedDocument document) async {
    // `kIsWeb` is a runtime check and is safe here precisely because the
    // platform-specific *import* was already resolved at compile time by
    // `pdf_opener.dart`. This check picks between two behaviours, not two
    // dependency sets.
    //
    // The `isOnDisk` half is the load-bearing one: a mobile build can also
    // reach here with no path if a store ever fails to write, and falling back
    // to the share sheet beats dereferencing a null path.
    if (kIsWeb || !document.isOnDisk) {
      return share(document.bytes, fileName: document.fileName);
    }
    await openDocumentAtPath(document.path!);
  }
}
