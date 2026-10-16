import 'package:steelforce/core/localization/localized_text.dart';

/// The one place that knows how a bilingual master-data field is spelled on
/// the wire and in a database row.
///
/// Three naming conventions are already in the codebase and all three are
/// load-bearing, so none of them can simply be renamed away:
///
///  * `name` / `nameKh` — the catalog feed and `products` table, matching SAP's
///    `MaterialDes` / `MaterialDesKH` pair;
///  * `enName` / `khName` — the depot master, matching SAP's BP `name1` /
///    `name3`;
///  * `name` / `name_kh` — Drift rows, which are snake_case.
///
/// Without a shared codec each model re-implements the same null/empty/fallback
/// handling, and they drift: one treats `''` as "no Khmer" and falls back,
/// another renders a blank label. That difference is invisible in English and
/// only shows up as an empty row after a rep switches to Khmer — the exact
/// class of bug this file exists to make impossible.
///
/// Deliberately free of Flutter and of the active locale: this is *parsing*,
/// not rendering. Rendering is [LocalizedTextContext.localized] (with a
/// `BuildContext`) or [ActiveLanguage] (without one).
class LocalizedTextCodec {
  const LocalizedTextCodec._();

  /// Reads a bilingual pair, trying each convention in turn.
  ///
  /// [enKeys]/[kmKeys] are ordered — the first key present and non-empty wins —
  /// so a feed migrating from one convention to another parses correctly while
  /// both spellings are in flight.
  static LocalizedText read(
    Map<String, dynamic> source, {
    required List<String> enKeys,
    required List<String> kmKeys,
  }) =>
      LocalizedText(
        en: _first(source, enKeys),
        km: _first(source, kmKeys),
      );

  /// The catalog convention: `name` + `nameKh` (JSON) or `name` + `name_kh`
  /// (Drift row). Accepts both so one call site serves feed and row parsing.
  static LocalizedText readName(Map<String, dynamic> source) => read(
        source,
        enKeys: const ['name'],
        kmKeys: const ['nameKh', 'name_kh'],
      );

  /// The depot-master convention: `enName` + `khName`, with [fallbackEn]
  /// used when SAP left `name1` blank.
  ///
  /// [fallbackEn] is what makes this safe to adopt on the depot directory:
  /// `shopName` is populated for every row, `enName` is not, so a depot with
  /// only a shop name still renders instead of going blank.
  static LocalizedText readBusinessName(
    Map<String, dynamic> source, {
    String? fallbackEn,
  }) {
    final text = read(
      source,
      enKeys: const ['enName', 'en_name'],
      kmKeys: const ['khName', 'kh_name'],
    );
    if (text.en.trim().isNotEmpty) return text;
    return LocalizedText(en: fallbackEn?.trim() ?? '', km: text.km);
  }

  /// Builds a pair from two already-extracted values, normalising `null` to
  /// `''`. The counterpart of [read] for callers that hold the fields directly
  /// (entity constructors, Drift companions) rather than a map.
  static LocalizedText of(String? en, String? km) =>
      LocalizedText(en: en?.trim() ?? '', km: km?.trim() ?? '');

  /// Like [of], but collapses a wholly-empty pair to `null` — for genuinely
  /// optional fields (a category description) where "absent" and "blank in
  /// both languages" should not render differently.
  static LocalizedText? ofOrNull(String? en, String? km) {
    final text = of(en, km);
    return text.isEmpty ? null : text;
  }

  static String _first(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key];
      if (value is String && value.trim().isNotEmpty) return value;
    }
    return '';
  }
}
