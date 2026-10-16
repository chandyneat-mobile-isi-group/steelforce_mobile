import 'package:equatable/equatable.dart';

enum ProductSortBy { relevance, nameAsc, priceAsc, priceDesc, stockDesc }

class ProductFilter extends Equatable {
  const ProductFilter({
    this.categoryId,
    this.familyId,
    this.subCategory,
    this.brand,
    this.warehouseCode,
    this.availableOnly = false,
    this.sortBy = ProductSortBy.relevance,
    this.size,
    this.length,
    this.width,
    this.height,
    this.grade,
    this.diameter,
    this.thickness,
    this.material,
  });

  final String? categoryId;

  /// Narrows to one product family (e.g. "Palm 70") — the level between a
  /// category and a sellable SKU. Used by the guided filter flow; null on the
  /// legacy browse path, where it is simply not part of the WHERE clause.
  final String? familyId;
  final String? subCategory;
  final String? brand;
  final String? warehouseCode;
  final bool availableOnly;
  final ProductSortBy sortBy;

  // Attribute filters mapped 1:1 onto the real Product columns (see
  // product_model.dart / catalog_database.dart): size/grade/material are
  // TEXT; length/width/height/diameter/thickness are REAL. "Mesh size" has no
  // dedicated column, so it's represented as a width+height pair; "Quality"
  // maps to `grade`. Which of these a category exposes is decided in the
  // presentation layer (category-dependent filters), but the entity carries
  // them all so a single ProductFilter round-trips through the SQL browse.
  final String? size;
  final double? length;
  final double? width;
  final double? height;
  final String? grade;
  final double? diameter;
  final double? thickness;
  final String? material;

  /// The size/length/mesh/quality/diameter/thickness/material facets only —
  /// i.e. everything the sequential attribute filter row can set. Category,
  /// brand, stock and sort are excluded on purpose.
  int get activeAttributeCount => [
        size,
        length,
        width,
        height,
        grade,
        diameter,
        thickness,
        material,
      ].where((v) => v != null).length;

  /// Total number of active, user-visible filter facets — drives the "active
  /// filter counter" badge. `width`+`height` collapse into a single "mesh
  /// size" facet so a mesh selection counts once, not twice.
  int get activeFacetCount {
    var count = activeAttributeCount;
    // Fold the width/height pair back into one facet.
    if (width != null && height != null) count -= 1;
    if (categoryId != null) count += 1;
    if (brand != null) count += 1;
    if (availableOnly) count += 1;
    return count;
  }

  bool get isEmpty =>
      categoryId == null &&
      familyId == null &&
      subCategory == null &&
      brand == null &&
      warehouseCode == null &&
      !availableOnly &&
      activeAttributeCount == 0;

  bool get hasActiveAttributes => activeAttributeCount > 0;

  /// Clears every attribute facet (size…material) while keeping category,
  /// brand, stock and sort — used when the user switches category, since the
  /// old size/grade/etc. rarely apply to the new category.
  ProductFilter clearAttributes() => ProductFilter(
        categoryId: categoryId,
        familyId: familyId,
        subCategory: subCategory,
        brand: brand,
        warehouseCode: warehouseCode,
        availableOnly: availableOnly,
        sortBy: sortBy,
      );

  ProductFilter copyWith({
    String? Function()? categoryId,
    String? Function()? familyId,
    String? Function()? subCategory,
    String? Function()? brand,
    String? Function()? warehouseCode,
    bool? availableOnly,
    ProductSortBy? sortBy,
    String? Function()? size,
    double? Function()? length,
    double? Function()? width,
    double? Function()? height,
    String? Function()? grade,
    double? Function()? diameter,
    double? Function()? thickness,
    String? Function()? material,
  }) {
    return ProductFilter(
      categoryId: categoryId != null ? categoryId() : this.categoryId,
      familyId: familyId != null ? familyId() : this.familyId,
      subCategory: subCategory != null ? subCategory() : this.subCategory,
      brand: brand != null ? brand() : this.brand,
      warehouseCode:
          warehouseCode != null ? warehouseCode() : this.warehouseCode,
      availableOnly: availableOnly ?? this.availableOnly,
      sortBy: sortBy ?? this.sortBy,
      size: size != null ? size() : this.size,
      length: length != null ? length() : this.length,
      width: width != null ? width() : this.width,
      height: height != null ? height() : this.height,
      grade: grade != null ? grade() : this.grade,
      diameter: diameter != null ? diameter() : this.diameter,
      thickness: thickness != null ? thickness() : this.thickness,
      material: material != null ? material() : this.material,
    );
  }

  @override
  List<Object?> get props => [
        categoryId,
        familyId,
        subCategory,
        brand,
        warehouseCode,
        availableOnly,
        sortBy,
        size,
        length,
        width,
        height,
        grade,
        diameter,
        thickness,
        material,
      ];
}
