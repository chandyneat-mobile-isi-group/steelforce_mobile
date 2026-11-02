/// The "Sales & Performance" step of depot registration (Q1–Q4 of the field
/// survey).
///
/// Pure Dart and mutable, like `BpDepotDraft` that owns it: the wizard writes
/// straight onto it. Amounts and shares are kept as the text the rep typed —
/// the form copies the draft back into its fields on every edit, and a parsed
/// number would turn "12." into "12" under the rep's cursor.
///
/// Saved with the draft only. The registration endpoint has no field for any
/// of this yet, so none of it is sent.
library;

/// Q1 — what the depot sells.
enum SurveyProductLine { steel, construction }

/// Q1.1 — which steel, asked only when [SurveyProductLine.steel] is picked.
enum SurveySteelType { tube, zincSheet, rebar }

/// Q4 — who the depot buys its steel from.
enum SteelSupplier { isi, gi, kbs, chipMong, others }

class DepotSalesSurvey {
  DepotSalesSurvey({
    Set<SurveyProductLine>? productLines,
    Set<SurveySteelType>? steelTypes,
    this.steelMonthlySales = '',
    this.constructionMonthlySales = '',
    this.shareToDepots = '',
    this.shareToEndUsers = '',
    Map<SteelSupplier, String>? steelPurchases,
  })  : productLines = productLines ?? <SurveyProductLine>{},
        steelTypes = steelTypes ?? <SurveySteelType>{},
        steelPurchases = steelPurchases ?? <SteelSupplier, String>{};

  final Set<SurveyProductLine> productLines;
  final Set<SurveySteelType> steelTypes;

  /// Q2 — average monthly sales in USD, 2026.
  String steelMonthlySales;
  String constructionMonthlySales;

  /// Q3 — share of steel sales value, in percent. Not a head count.
  String shareToDepots;
  String shareToEndUsers;

  /// Q4 — average monthly steel purchases in USD, by supplier. Optional.
  final Map<SteelSupplier, String> steelPurchases;

  bool get sellsSteel => productLines.contains(SurveyProductLine.steel);
  bool get sellsConstruction =>
      productLines.contains(SurveyProductLine.construction);

  /// Q2 total. Only the lines the depot sells count.
  double get totalMonthlySales =>
      (sellsSteel ? amount(steelMonthlySales) ?? 0 : 0) +
      (sellsConstruction ? amount(constructionMonthlySales) ?? 0 : 0);

  /// Picks or drops a product line. Dropping steel clears the steel-only
  /// answers, so a later backend never receives figures for a line the depot
  /// does not sell.
  void setProductLine(SurveyProductLine line, bool selected) {
    if (selected) {
      productLines.add(line);
      return;
    }
    productLines.remove(line);
    if (line == SurveyProductLine.steel) {
      steelTypes.clear();
      steelMonthlySales = '';
      shareToDepots = '';
      shareToEndUsers = '';
      steelPurchases.clear();
    } else {
      constructionMonthlySales = '';
    }
  }

  /// Q3 has two blanks that must make 100, so typing one fills the other.
  void setShareToDepots(String value) {
    shareToDepots = value;
    shareToEndUsers = _complement(value);
  }

  void setShareToEndUsers(String value) {
    shareToEndUsers = value;
    shareToDepots = _complement(value);
  }

  static String _complement(String value) {
    final n = int.tryParse(value.trim());
    return (n == null || n < 0 || n > 100) ? '' : '${100 - n}';
  }

  /// A non-negative amount, or null when blank or unreadable.
  static double? amount(String raw) {
    final n = double.tryParse(raw.trim());
    return (n == null || n < 0 || !n.isFinite) ? null : n;
  }

  /// Field key -> i18n error key, the same shape as `BpDepotDraft.validateStep`.
  Map<String, String> validate() {
    final e = <String, String>{};
    if (productLines.isEmpty) {
      e['surveyProductLines'] = 'error.pick_at_least_one';
    }
    if (sellsSteel) {
      if (steelTypes.isEmpty) e['surveySteelTypes'] = 'error.pick_at_least_one';
      _requireAmount(e, 'surveySteelSales', steelMonthlySales);
      final depots = int.tryParse(shareToDepots.trim());
      final endUsers = int.tryParse(shareToEndUsers.trim());
      if (depots == null || endUsers == null) {
        e['surveyShare'] = 'error.required';
      } else if (depots < 0 || endUsers < 0 || depots + endUsers != 100) {
        e['surveyShare'] = 'error.share_total_100';
      }
      for (final entry in steelPurchases.entries) {
        if (entry.value.trim().isNotEmpty && amount(entry.value) == null) {
          e['surveyPurchase_${entry.key.name}'] = 'error.invalid_amount';
        }
      }
    }
    if (sellsConstruction) {
      _requireAmount(e, 'surveyConstructionSales', constructionMonthlySales);
    }
    return e;
  }

  static void _requireAmount(Map<String, String> e, String key, String raw) {
    if (raw.trim().isEmpty) {
      e[key] = 'error.required';
    } else if (amount(raw) == null) {
      e[key] = 'error.invalid_amount';
    }
  }

  Map<String, dynamic> toJson() => {
        'productLines': [for (final l in productLines) l.name],
        'steelTypes': [for (final t in steelTypes) t.name],
        'steelMonthlySales': steelMonthlySales,
        'constructionMonthlySales': constructionMonthlySales,
        'shareToDepots': shareToDepots,
        'shareToEndUsers': shareToEndUsers,
        'steelPurchases': {
          for (final p in steelPurchases.entries) p.key.name: p.value,
        },
      };

  /// Tolerant: an unknown option or a missing key is skipped, never thrown on,
  /// so a draft saved by another app version still opens.
  static DepotSalesSurvey fromJson(Object? raw) {
    if (raw is! Map) return DepotSalesSurvey();
    String text(String key) => raw[key]?.toString() ?? '';
    Set<T> pick<T extends Enum>(List<T> values, Object? list) => {
          if (list is List)
            for (final v in list)
              ...values.where((e) => e.name == v.toString()),
        };
    final purchases = raw['steelPurchases'];
    return DepotSalesSurvey(
      productLines: pick(SurveyProductLine.values, raw['productLines']),
      steelTypes: pick(SurveySteelType.values, raw['steelTypes']),
      steelMonthlySales: text('steelMonthlySales'),
      constructionMonthlySales: text('constructionMonthlySales'),
      shareToDepots: text('shareToDepots'),
      shareToEndUsers: text('shareToEndUsers'),
      steelPurchases: {
        if (purchases is Map)
          for (final s in SteelSupplier.values)
            if (purchases[s.name] != null) s: purchases[s.name].toString(),
      },
    );
  }
}
