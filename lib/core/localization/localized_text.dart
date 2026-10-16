import 'package:equatable/equatable.dart';

/// A single piece of master data carried in every language the app ships.
///
/// The alternative — one dataset per locale (`products_en.json`,
/// `products_kh.json`) — is what this exists to prevent. Two datasets drift:
/// a SKU added to one and not the other silently disappears when the rep
/// switches language, and every sync has to reconcile N copies of the same
/// row. SAP sends `MaterialDes` and `MaterialDesKH` on the *same* material
/// record, so the app stores them the same way and picks at render time.
///
/// Immutable and value-equal, so it can sit inside an entity without breaking
/// the `Equatable` comparisons the blocs rely on to suppress rebuilds.
class LocalizedText extends Equatable {
  const LocalizedText({required this.en, required this.km});

  /// Both languages hold the same text — for values that genuinely aren't
  /// translated (a material number, a grade code like `G300AZ100`).
  const LocalizedText.same(String value)
      : en = value,
        km = value;

  final String en;

  /// Khmer. May be empty: SAP does not carry `MaterialDesKH` for every
  /// material, and an empty string here is meaningful — it means "no Khmer
  /// text exists", which [resolve] handles by falling back rather than
  /// rendering a blank label.
  final String km;

  /// The text to show for [languageCode].
  ///
  /// Falls back to English when Khmer is missing rather than showing an empty
  /// row: a rep who cannot read the English name can still match the material
  /// number next to it, whereas a blank line is unrecoverable.
  String resolve(String languageCode) {
    if (languageCode == 'km' && km.trim().isNotEmpty) return km;
    return en.trim().isNotEmpty ? en : km;
  }

  /// Every language's text, for search indexing.
  ///
  /// Search deliberately spans *both* languages regardless of the active
  /// locale: a rep typing a Khmer product name while the UI is in English is
  /// looking for that product, and finding nothing would be a bug, not
  /// correct behaviour.
  Iterable<String> get allValues sync* {
    if (en.trim().isNotEmpty) yield en;
    if (km.trim().isNotEmpty && km != en) yield km;
  }

  bool get isEmpty => en.trim().isEmpty && km.trim().isEmpty;

  @override
  List<Object?> get props => [en, km];

  @override
  String toString() => en.isNotEmpty ? en : km;
}
