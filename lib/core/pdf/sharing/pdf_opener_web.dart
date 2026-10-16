/// Web: unreachable by construction.
///
/// `PdfShareServiceImpl.openSaved` routes every web call to the share/download
/// path before it can get here, because on web a [SavedDocument] never has a
/// path to open. This exists only so `open_filex` — which has no web
/// implementation — never reaches a web compile.
///
/// It throws rather than silently doing nothing: reaching this function means
/// something invented a filesystem path in a browser, which is a bug worth
/// surfacing loudly during development rather than a condition to absorb.
Future<void> openDocumentAtPath(String path) async {
  throw UnsupportedError(
    'Opening a file path is not possible on web. '
    'PdfShareService.openSaved offers the bytes as a download instead.',
  );
}
