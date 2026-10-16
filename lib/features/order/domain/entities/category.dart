import 'package:equatable/equatable.dart';
import 'package:steelforce/core/localization/localized_text.dart';

/// A node in the product taxonomy.
///
/// Two things are deliberately separated here, because conflating them is what
/// made the previous version unable to grow:
///
///  * **How ISI sells** — the tree a rep navigates ("ISI Pipe" → "Square
///    Pipe"). Parents exist purely to group; only leaves carry products.
///  * **What SAP calls it** — [code], the `ProductGroup`/`MaterialGroupName`
///    this node maps onto. Renaming a branch for the sales team never touches
///    the SAP mapping, and a SAP regrouping never forces a UI redesign.
///
/// [name] is a [LocalizedText] rather than a `String`, so no widget ever needs
/// a translation lookup for a category label — the label *is* the data. That
/// is what makes a language switch a rebuild rather than a re-fetch.
class Category extends Equatable {
  const Category({
    required this.id,
    required this.code,
    required this.name,
    required this.displayOrder,
    this.parentId,
    this.description,
    this.icon,
    this.active = true,
    this.createdAt,
    this.updatedAt,
  });

  final String id;

  /// SAP-side identifier for this node. Stable across renames, which is why
  /// sync matches on it rather than on the display name.
  final String code;

  final LocalizedText name;

  /// Null for a top-level node. A category with children is a *grouping* — the
  /// finder walks into it rather than querying products for it.
  final String? parentId;

  final LocalizedText? description;

  /// Icon key, not a widget or a codepoint — the domain must not depend on
  /// Flutter. Presentation maps it; an unknown key falls back rather than
  /// crashing, so SAP can add a category before the app knows its icon.
  final String? icon;

  final int displayOrder;

  /// Retired categories stay in the table so historical quotation lines still
  /// resolve their category, but they are never offered for new selection.
  final bool active;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isTopLevel => parentId == null;

  /// Convenience for the common render path.
  String label(String languageCode) => name.resolve(languageCode);

  Category copyWith({
    String? id,
    String? code,
    LocalizedText? name,
    String? Function()? parentId,
    LocalizedText? Function()? description,
    String? Function()? icon,
    int? displayOrder,
    bool? active,
    DateTime? Function()? createdAt,
    DateTime? Function()? updatedAt,
  }) {
    return Category(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      parentId: parentId != null ? parentId() : this.parentId,
      description: description != null ? description() : this.description,
      icon: icon != null ? icon() : this.icon,
      displayOrder: displayOrder ?? this.displayOrder,
      active: active ?? this.active,
      createdAt: createdAt != null ? createdAt() : this.createdAt,
      updatedAt: updatedAt != null ? updatedAt() : this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        code,
        name,
        parentId,
        description,
        icon,
        displayOrder,
        active,
        createdAt,
        updatedAt,
      ];
}
