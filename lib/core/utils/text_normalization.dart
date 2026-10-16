/// Text normalisation shared by every depot search path.
///
/// ## Why this exists
///
/// SAP's Khmer master data carries **zero-width characters** as word-break
/// hints — `U+200B` (space), `U+200C` (non-joiner), `U+200D` (joiner). In the
/// current production extract, 1,130 of 5,990 Khmer names contain at least one
/// (`docs/feature/depot/mobile/search-depot.md` §Khmer search).
///
/// They are invisible on screen. A representative reads a shop's name off the
/// list, types it back, and a naive `LIKE` finds nothing:
///
/// ```text
/// stored    ដេប៉ូ<ZWSP><ZWSP><ZWSP> រស្មី សៀមរាប
/// typed     ដេប៉ូ រស្មី សៀមរាប
/// ```
///
/// The server strips these from both the term and the name columns before
/// comparing. **Local search has to do the same**, or the offline directory
/// answers differently from the online one — and answers wrongly for roughly a
/// fifth of Khmer names.
library;

/// The zero-width characters SAP embeds in Khmer text.
///
/// Deliberately only these three. Stripping a broader class (e.g. all `Cf`
/// format characters) would also remove the bidirectional marks that legitimately
/// change how a string renders.
const List<String> kZeroWidthCharacters = <String>[
  '\u200B', // ZERO WIDTH SPACE
  '\u200C', // ZERO WIDTH NON-JOINER
  '\u200D', // ZERO WIDTH JOINER
];

/// Removes SAP's zero-width word-break hints.
///
/// Apply to **both** sides of a comparison. Stripping only the stored value, or
/// only the typed term, leaves the mismatch in place.
String stripZeroWidth(String value) {
  if (value.isEmpty) return value;
  var result = value;
  for (final character in kZeroWidthCharacters) {
    if (result.contains(character)) {
      result = result.replaceAll(character, '');
    }
  }
  return result;
}

/// True when the input looks like a phone number a rep pasted or typed with
/// human formatting.
///
/// Six characters minimum so a short numeric shop code is not mistaken for a
/// phone number and stripped of characters that matter to it.
bool looksLikePhone(String term) => RegExp(r'^[\d\s+()\-]{6,}$').hasMatch(term);

/// Normalises a free-text depot search term.
///
/// Two transformations, and no others:
///
///  * zero-width characters are removed, so Khmer text matches what SAP stored;
///  * phone-shaped input is reduced to digits and a leading `+`, because phone
///    numbers are normalised on write — `012 345 678` is stored as `012345678`,
///    so searching `012 345` would otherwise match nothing.
///
/// Khmer and Latin text is otherwise passed through verbatim. The server does
/// no case folding for Khmer (the script has no case), and inventing further
/// client-side cleverness would make the local and remote results diverge.
String normalizeSearchTerm(String raw) {
  final trimmed = stripZeroWidth(raw.trim());
  if (trimmed.isEmpty) return '';
  return looksLikePhone(trimmed)
      ? trimmed.replaceAll(RegExp(r'[^0-9+]'), '')
      : trimmed;
}
