/// A bundled test image the stand-in camera can return.
///
/// Synthetic placeholders, drawn programmatically — **no real depot
/// photographs, documents or personal information** is bundled with the app
/// (`docs/skills/security.md` §3).
enum MockCameraAsset {
  storefront('storefront.png', 'Storefront'),
  insideStore('inside_store.png', 'Inside store'),
  idCard('id_card.png', 'ID card'),
  document('document.png', 'Document'),
  material('material.png', 'Material');

  const MockCameraAsset(this.fileName, this.label);

  final String fileName;

  /// Shown in the picker. English only and deliberately un-localised: this is
  /// developer-facing scaffolding that never reaches a representative.
  final String label;

  static const String directory = 'assets/mock/camera';

  String get assetPath => '$directory/$fileName';

  /// The default a capture returns when nothing has been chosen — the most
  /// common shot in the field flows.
  static const MockCameraAsset fallback = MockCameraAsset.storefront;
}
