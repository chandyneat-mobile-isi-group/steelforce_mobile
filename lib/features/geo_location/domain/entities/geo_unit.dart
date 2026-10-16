import 'package:equatable/equatable.dart';
import 'package:steelforce/core/localization/localized_text.dart';

/// One rung of the Cambodian administrative hierarchy.
///
/// Ordered parent-first, so `GeoLevel.values.indexOf` doubles as depth and the
/// cascade can talk about "every level below this one" without a lookup table
/// (see [deeperLevels], which is what the reset logic iterates).
enum GeoLevel {
  province,
  district,
  commune,
  village;

  /// The levels that depend on this one, deepest last.
  ///
  /// This is the whole cascading-reset rule in one place. The alternative —
  /// each selector clearing the three fields it happens to know about — is what
  /// the old bottom sheet did, and it cleared district and postal code on a
  /// province change while leaving nothing to clear commune or village because
  /// neither existed yet. Adding a level there would have meant finding every
  /// such site; here it means adding an enum case.
  List<GeoLevel> get deeperLevels =>
      GeoLevel.values.where((l) => l.index > index).toList(growable: false);

  /// The level this one hangs off, or null for [province].
  GeoLevel? get parent => index == 0 ? null : GeoLevel.values[index - 1];

  /// Number of digits in a valid code at this level. The NCDD codes are
  /// strictly hierarchical — a district code is its province's code plus two
  /// digits — which is what [GeoUnit.isChildOf] checks.
  int get codeLength => (index + 1) * 2;

  String get labelKey => switch (this) {
        GeoLevel.province => 'geo.province',
        GeoLevel.district => 'geo.district',
        GeoLevel.commune => 'geo.commune',
        GeoLevel.village => 'geo.village',
      };
}

/// A selectable place at one [level] of the hierarchy.
///
/// One type for all four levels rather than four near-identical classes. The
/// selector widget, the picker sheet, the search and the reset logic are
/// genuinely level-agnostic — they differ only in which list they are handed —
/// and four types would have forced each of them to exist four times or to be
/// generic over a marker interface that carried no extra information.
///
/// The two things that genuinely differ by level are modelled as data:
/// [postalCode], which only a commune carries, and [unit], which is the word
/// the address is written with.
class GeoUnit extends Equatable {
  const GeoUnit({
    required this.level,
    required this.code,
    required this.name,
    required this.unit,
    this.parentCode,
    this.postalCode,
  });

  final GeoLevel level;

  /// The NCDD code — `'12'`, `'1201'`, `'120101'`, `'12010101'`.
  ///
  /// **This is the identity and the submitted value.** Names are localised and
  /// several villages share one; the code is the only stable handle.
  final String code;

  /// Both languages, resolved at render time by `context.localized`.
  final LocalizedText name;

  /// The administrative word: `Province`, `Capital`, `District`,
  /// `Municipality`, `Khan`, `Commune`, `Sangkat`, `Village`.
  ///
  /// Carried because a Cambodian address is not "Chamkar Mon District" — it is
  /// "Khan Chamkar Mon", and Phnom Penh is a capital, not a province. Dropping
  /// this produces addresses that read as machine-generated.
  final String unit;

  /// The parent's code, or null for a province.
  final String? parentCode;

  /// Set only on a commune, and null there for the 99 communes Cambodia Post
  /// does not unambiguously cover. See [GeoAddress.postalCode].
  final String? postalCode;

  /// Whether this unit is a child of [parentCode] structurally.
  ///
  /// Checks the code prefix rather than trusting [parentCode], because the
  /// prefix is a property of the value itself and survives a round trip through
  /// a saved form, an API payload or a Drift row. This is the data-integrity
  /// check the spec asks for at §14 — enforced in the domain, not in the UI.
  bool isChildOf(String candidateParentCode) =>
      code.length == level.codeLength &&
      code.startsWith(candidateParentCode) &&
      candidateParentCode.length == (level.parent?.codeLength ?? 0);

  @override
  List<Object?> get props => [level, code];
}
