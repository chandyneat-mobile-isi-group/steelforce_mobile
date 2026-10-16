import 'package:equatable/equatable.dart';

/// Where a material's sellability check currently stands.
///
/// Deliberately four states, not a bool. "Not yet asked", "asking" and "the
/// answer is no" are three different things to a rep standing in front of a
/// depot, and collapsing them means a card that has not been checked looks
/// identical to one SAP refused.
enum MaterialStockStatus {
  /// Never asked. The default for every material the rep is only browsing —
  /// the check is a live SAP round trip and is spent on commitment, not on
  /// scrolling.
  unknown,

  checking,

  /// SAP says this may be sold into the sales area.
  available,

  /// SAP says it may not. **This is not a quantity.** There is no on-hand
  /// figure anywhere in this API; the verdict is about whether the material is
  /// sellable at all, which is a different question from how much is in the
  /// yard.
  unavailable,
}

/// How much of a material SAP says is on hand, as a band rather than a figure.
///
/// The stock endpoint answers `"High"` / `"Medium"` / `"Low"` / `"None"`, never
/// a quantity, and that is a deliberate choice on the server's part rather than
/// a gap: an exact count on a card is a number a rep will read as a promise the
/// moment it goes stale.
enum StockBand {
  /// No band was reported. Distinct from [none] — "not told" rather than
  /// "told there is nothing".
  unknown,

  none,
  low,
  medium,
  high;

  /// Parses SAP's own casing. An unrecognised band degrades to [unknown]
  /// rather than to [none]: inventing "there is no stock" out of a string this
  /// build has not seen would stop a sale that should have gone ahead.
  static StockBand parse(String? raw) => switch (raw?.trim().toLowerCase()) {
        'high' => StockBand.high,
        'medium' || 'mid' => StockBand.medium,
        'low' => StockBand.low,
        'none' || 'zero' || 'out' => StockBand.none,
        _ => StockBand.unknown,
      };
}

/// One plant's own verdict on a material.
///
/// The material-level answer is the roll-up; this is the breakdown. A rep who
/// is told "High" still needs to know *where*, because a depot two provinces
/// away is not the same offer as the one down the road.
class MaterialPlantStock extends Equatable {
  const MaterialPlantStock({
    required this.plant,
    required this.band,
    required this.isSellable,
  });

  final String plant;
  final StockBand band;
  final bool isSellable;

  @override
  List<Object?> get props => [plant, band, isSellable];
}

/// One line of SAP's reasoning.
///
/// The working, not just the conclusion: `SALES_VIEW` failing with "Material is
/// not extended to sales area 1000/10" is the difference between a rep being
/// told "cannot sell this" and being told something they can act on by phoning
/// the right person.
class MaterialAvailabilityCheck extends Equatable {
  const MaterialAvailabilityCheck({
    required this.sequence,
    required this.checkId,
    required this.status,
    required this.message,
    required this.isVerdict,
  });

  final String sequence;
  final String checkId;

  /// SAP's own status letter: `S` success, `E` error.
  final String status;

  final String message;

  /// True for the single concluding check. The others are how it got there.
  final bool isVerdict;

  bool get isError => status.toUpperCase() == 'E';

  /// A complaint about what *we* sent, not about the material.
  ///
  /// SAP answers `INPUT_VKORG` / `INPUT_VTWEG` when the sales-area parameters
  /// are missing, and it does so with **HTTP 200** — the request succeeded, the
  /// validation simply never ran. Reading that as a business verdict is the
  /// documented trap.
  bool get isInputProblem => checkId.toUpperCase().startsWith('INPUT_');

  @override
  List<Object?> get props => [sequence, checkId, status, message, isVerdict];
}

/// SAP's live sellability verdict for one material in one sales area.
///
/// **Not a stock level.** The materials API exposes no on-hand quantity, no
/// warehouse balance and no ATP figure. What it exposes is this: whether the
/// ERP will accept an order line for the material, and why not when it will
/// not.
class MaterialAvailability extends Equatable {
  const MaterialAvailability({
    required this.material,
    required this.isSellable,
    required this.summary,
    this.checks = const [],
    this.band = StockBand.unknown,
    this.baseUnit = '',
    this.plants = const [],
    this.checkedAt,
    this.status = MaterialStockStatus.unknown,
  });

  /// The in-flight placeholder, so a card can show a spinner against the exact
  /// material being checked rather than a screen-wide loading state.
  const MaterialAvailability.checking(this.material)
      : isSellable = false,
        summary = '',
        checks = const [],
        band = StockBand.unknown,
        baseUnit = '',
        plants = const [],
        checkedAt = null,
        status = MaterialStockStatus.checking;

  final String material;
  final bool isSellable;

  /// SAP's own one-line conclusion, already written for a human.
  final String summary;

  /// SAP's working, from the sales-area validation endpoint. Empty for a stock
  /// read, which answers a band instead of a chain of checks.
  final List<MaterialAvailabilityCheck> checks;

  /// How much is on hand, banded. [StockBand.unknown] where the answer came
  /// from the sellability endpoint, which reports no quantity at all.
  final StockBand band;

  /// The material's own unit — `KG` for coil, `M` for profile. Read per
  /// material, never assumed.
  final String baseUnit;

  /// Per-plant breakdown behind [band].
  final List<MaterialPlantStock> plants;

  /// When SAP computed this. Worth carrying: a band is a snapshot, and a rep
  /// deciding on a large line is entitled to know how fresh it is.
  final DateTime? checkedAt;

  final MaterialStockStatus status;

  /// Whether the rep may put this material on an order line.
  ///
  /// The single question the quantity stepper asks. Note what it does *not*
  /// consult: the band. A `Low` band is still sellable — it is a warning about
  /// how much, not a refusal — and gating the `+` on it would block orders SAP
  /// would happily accept.
  bool get canOrder => switch (status) {
        MaterialStockStatus.available => true,
        MaterialStockStatus.unavailable => false,
        // Never asked, or still asking. The rep is not blocked on a question
        // that has not been answered yet.
        MaterialStockStatus.unknown || MaterialStockStatus.checking => true,
      };

  /// The plants that can actually supply this material.
  List<MaterialPlantStock> get sellablePlants =>
      plants.where((p) => p.isSellable).toList(growable: false);

  /// The concluding check, or null when SAP returned only working.
  MaterialAvailabilityCheck? get verdict {
    for (final check in checks) {
      if (check.isVerdict) return check;
    }
    return null;
  }

  /// Everything that actually blocked the sale, in SAP's own order — the
  /// verdict excluded, because it restates rather than explains.
  List<MaterialAvailabilityCheck> get blockingChecks =>
      checks.where((c) => c.isError && !c.isVerdict).toList(growable: false);

  /// The check failed because the app did not send the sales area, not because
  /// the material is unsellable.
  ///
  /// SAP needs `salesOrg`, `disChannel` and `division`; without them it answers
  /// "Validation not performed. Mandatory input parameters are missing." with
  /// `isSellable: false`. That `false` is the absence of an answer wearing the
  /// shape of one.
  ///
  /// Kept as its own flag so the reason survives into logs and the detail sheet
  /// even where the badge treats it as a plain "no stock" — a rep should not be
  /// the last person to find out the handset never asked the question properly.
  bool get isInputIncomplete => checks.any((c) => c.isInputProblem);

  /// The single line worth putting under a badge.
  ///
  /// Prefers the first genuine blocker over the verdict, because the verdict
  /// only ever restates the summary while the blocker names the cause.
  String get reason {
    final blocking = blockingChecks;
    if (blocking.isNotEmpty) return blocking.first.message;
    return verdict?.message ?? summary;
  }

  @override
  List<Object?> get props => [
        material,
        isSellable,
        summary,
        checks,
        band,
        baseUnit,
        plants,
        checkedAt,
        status,
      ];
}
