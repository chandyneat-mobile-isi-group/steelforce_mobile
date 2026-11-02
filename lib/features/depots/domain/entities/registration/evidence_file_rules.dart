/// The server's evidence-file rules (`attachments.md`, deployment defaults),
/// checked on the phone so a rep on a slow link learns about a wrong file
/// before spending the upload. The server stays the authority: it also checks
/// the file's first bytes, which a name alone cannot prove.
abstract final class EvidenceFileRules {
  static const int megabyte = 1024 * 1024;

  /// `DEPOT_ATTACHMENT_MAX_IMAGE_MB` / `_MAX_DOCUMENT_MB` defaults.
  static const int maxImageBytes = 10 * megabyte;
  static const int maxDocumentBytes = 10 * megabyte;

  /// `DEPOT_ATTACHMENT_MAX_PER_DRAFT` / `_MAX_TOTAL_MB` defaults. The server
  /// does not publish its configured values, so these are what the app can
  /// know; a stricter server answers 409 and that answer wins.
  static const int maxFilesPerDraft = 20;
  static const int maxTotalBytes = 100 * megabyte;

  static const int maxNoteLength = 200;

  /// Media type per accepted extension: JPG, PNG, WebP, PDF, DOCX.
  static const Map<String, String> _mediaTypes = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
    'pdf': 'application/pdf',
    'docx':
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  };

  static String _extension(String fileName) {
    final dot = fileName.lastIndexOf('.');
    return dot < 0 ? '' : fileName.substring(dot + 1).toLowerCase();
  }

  /// The media type to declare for [fileName], or null when the server would
  /// refuse its type outright.
  static String? mediaTypeFor(String fileName) =>
      _mediaTypes[_extension(fileName)];

  static bool isImage(String fileName) =>
      mediaTypeFor(fileName)?.startsWith('image/') ?? false;

  /// Why [fileName] of [sizeBytes] cannot be sent, or null when it may be.
  static EvidenceFileProblem? check(String fileName, int sizeBytes) {
    if (mediaTypeFor(fileName) == null) return EvidenceFileProblem.type;
    if (sizeBytes <= 0) return EvidenceFileProblem.empty;
    final cap = isImage(fileName) ? maxImageBytes : maxDocumentBytes;
    return sizeBytes > cap ? EvidenceFileProblem.tooLarge : null;
  }
}

enum EvidenceFileProblem { type, empty, tooLarge }
