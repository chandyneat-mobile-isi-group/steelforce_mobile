import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// A generated document that has been handed to the platform's storage.
///
/// Replaces the `dart:io` `File` that used to travel through the PDF services
/// and into `PdfGenerationState`. A `File` in a Cubit state is a `dart:io` type
/// in the presentation layer, which is both a web-compile blocker and a layering
/// smell the web work surfaced rather than caused.
///
/// ## Why it carries [bytes] as well as [path]
///
/// The two platforms disagree about when a document becomes a file:
///
/// - **Android/iOS** — [path] points inside the app sandbox; the file exists and
///   can be reopened later by any viewer.
/// - **Web** — there is no filesystem the app may write to. [path] is null and
///   the document only exists as [bytes] in memory until the user chooses to
///   download or print it.
///
/// Carrying the bytes lets "re-open the last document" work identically on both:
/// mobile reopens the path, web re-offers the same bytes. The alternative —
/// regenerating the PDF on every share — would be slower and could produce a
/// *different* document if any input changed in between.
class SavedDocument extends Equatable {
  const SavedDocument({
    required this.fileName,
    required this.bytes,
    this.path,
  });

  /// Display/download name, always present. Includes the `.pdf` extension.
  final String fileName;

  /// The document itself. Kept in memory so web can act on it later.
  final Uint8List bytes;

  /// Absolute path inside the app sandbox, or null on web.
  final String? path;

  /// True when the document survives beyond this session — mobile only.
  ///
  /// Callers that want to say "saved to your device" should check this rather
  /// than assuming it; on web nothing was saved anywhere until the user accepts
  /// a download.
  bool get isOnDisk => path != null;

  @override
  List<Object?> get props => [fileName, path, bytes.length];
}
