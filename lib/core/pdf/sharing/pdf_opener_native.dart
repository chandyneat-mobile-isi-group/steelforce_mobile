import 'package:open_filex/open_filex.dart';

/// Android/iOS: hand the saved file to the platform's default PDF viewer.
/// Selected by the conditional export in `pdf_opener.dart`.
Future<void> openDocumentAtPath(String path) async {
  await OpenFilex.open(path);
}
