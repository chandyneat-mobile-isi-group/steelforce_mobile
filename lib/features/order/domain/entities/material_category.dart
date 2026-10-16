import 'package:equatable/equatable.dart';
import 'package:steelforce/core/localization/localized_text.dart';

/// A category that opens the guided material finder.
///
/// Deliberately **not** [Category]. That entity models the sales taxonomy the
/// app carries locally — a tree with parents, icons, display order and a SAP
/// mapping. This one models what stage zero of the finder actually answers:
/// SAP's `MaterialGroupCategory`, how many live materials sit behind it, and
/// whether a wizard has been defined for it at all.
///
/// The two extra fields are the whole reason for the separate type, and both
/// change what the UI may do:
///
///  * [materialCount] is worth showing — it tells the rep how big a haystack
///    they are walking into before they spend a tap.
///  * [hasPublishedSchema] tells the UI whether the first schema read will use
///    merchandising's published hierarchy. Categories without one are still
///    offerable: the selection API derives a safe, optional hierarchy for that
///    named category from its live material data.
class MaterialCategory extends Equatable {
  const MaterialCategory({
    required this.code,
    required this.name,
    required this.materialCount,
    required this.hasPublishedSchema,
    this.icon,
  });

  /// SAP's `MaterialGroupCategory` — `FG-RF`, `FG-PIPE`, `SP-MECH`. This is
  /// the identity everywhere: it is what `selection/schema` is asked for and
  /// what rides in every `selection` object as `categoryCode`.
  final String code;

  /// Already localised by the server from `Accept-Language`, and carried as
  /// [LocalizedText] so the rest of the app renders it the same way it renders
  /// every other label — no translation lookup, and a language switch is a
  /// rebuild rather than a re-fetch.
  ///
  /// Falls back to [code] when no hierarchy names the category.
  final LocalizedText name;

  final int materialCount;
  final bool hasPublishedSchema;

  /// Icon key, not a widget or a codepoint — the domain must not depend on
  /// Flutter. Presentation maps it and falls back rather than crashing, so the
  /// server can publish a category before the app knows an icon for it.
  final String? icon;

  /// Whether this category may be offered as an entry point.
  ///
  /// A named category without a published schema still receives a derived
  /// hierarchy from the API; only an empty category has nowhere to go.
  bool get isOfferable => materialCount > 0;

  String label(String languageCode) => name.resolve(languageCode);

  @override
  List<Object?> get props => [code, name, materialCount, hasPublishedSchema];
}
