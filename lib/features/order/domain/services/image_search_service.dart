/// Where the product photo for an image search comes from.
enum ImageSearchSource { camera, gallery }

/// Turns a physical product photo into a catalog search query. In a real
/// deployment the picked image bytes are POSTed to a multi-modal embedding
/// endpoint that returns the closest-matching SKUs; the app only ever sees the
/// resolved query/keyword, so — like [BarcodeScannerService] — the domain
/// stays free of any picker/UI or networking detail.
abstract interface class ImageSearchService {
  /// Lets the user pick/capture a product photo from [source], runs it through
  /// the (mock) visual-match pipeline, and resolves with the matched search
  /// query — or `null` if the user cancelled or nothing matched.
  Future<String?> matchQuery(ImageSearchSource source);
}
