import 'package:drift/drift.dart' show Value;
import 'package:steelforce/core/database/drift/app_database.dart' as db;
import 'package:steelforce/core/database/drift/daos/catalog_dao.dart';
import 'package:steelforce/core/localization/localized_text.dart';
import 'package:steelforce/features/order/data/models/category_model.dart';
import 'package:steelforce/features/order/data/models/product_model.dart';
import 'package:steelforce/features/order/domain/entities/product_filter.dart';

/// Mapping between the Order feature models and the encrypted catalog tables.
///
/// The **read** path deliberately reuses [ProductModel.fromRow] against the
/// joined `QueryRow.data` (identical column aliases to the legacy SQL), so only
/// the write path needs explicit companion builders here.

extension ProductModelCatalogMapper on ProductModel {
  db.ProductsCompanion toProductCompanion() => db.ProductsCompanion.insert(
        id: id,
        familyId: familyId,
        familyName: familyName,
        code: code,
        sku: sku,
        materialCode: materialCode,
        barcode: barcode,
        name: name,
        nameKh: Value(nameKh),
        description: description,
        color: Value(color),
        specification: Value(specification),
        createdAt: Value(createdAt),
        categoryId: categoryId,
        subCategory: subCategory,
        brand: brand,
        grade: grade,
        material: material,
        size: size,
        diameter: diameter,
        thickness: thickness,
        length: length,
        width: width,
        height: height,
        weight: weight,
        unit: unit,
        warehouseCode: warehouseCode,
        territory: territory,
        businessUnit: businessUnit,
        imageUrl: imageUrl,
        isMto: Value(isMto),
        status: Value(status.name),
        updatedAt: updatedAt,
        deleted: Value(deleted),
        minStock: Value(minStock),
        maxStock: Value(maxStock),
      );

  db.PricesCompanion toPriceCompanion() => db.PricesCompanion.insert(
        productId: id,
        costPrice: pricing.costPrice,
        standardPrice: pricing.standardPrice,
        wholesalePrice: pricing.wholesalePrice,
        dealerPrice: pricing.dealerPrice,
        vipPrice: pricing.vipPrice,
        creditPrice: pricing.creditPrice,
        cashPrice: pricing.cashPrice,
        promotionPrice: Value(pricing.promotionPrice),
        promotionType: Value(pricing.promotionType?.name),
        promotionLabel: Value(pricing.promotionLabel),
        currency: pricing.currency,
        updatedAt: updatedAt,
      );

  db.StockCompanion toStockCompanion() => db.StockCompanion.insert(
        productId: id,
        warehouseCode: warehouseCode,
        quantity: stockQuantity,
        reserved: reservedQuantity,
        updatedAt: updatedAt,
      );
}

extension CategoryModelCatalogMapper on CategoryModel {
  db.CategoriesCompanion toCompanion() => db.CategoriesCompanion.insert(
        id: id,
        // `name` stays the English column so v14 rows and every existing read
        // keep working; Khmer lands beside it rather than replacing it.
        name: name.en,
        nameKh: Value(name.km),
        code: Value(code),
        parentId: Value(parentId),
        description: Value(description?.en),
        descriptionKh: Value(description?.km),
        icon: Value(icon),
        sortOrder: Value(displayOrder),
        active: Value(active),
        createdAt: Value(createdAt),
        updatedAt: Value(updatedAt),
      );
}

extension CategoryRowCatalogMapper on db.Category {
  CategoryModel toModel() => CategoryModel(
        id: id,
        parentId: parentId,
        // Older rows predate the code column; the id is a stable stand-in and
        // keeps the node addressable until the next sync backfills it.
        code: code.trim().isEmpty ? id : code,
        name: LocalizedText(en: name, km: nameKh),
        description:
            (description ?? '').isEmpty && (descriptionKh ?? '').isEmpty
                ? null
                : LocalizedText(en: description ?? '', km: descriptionKh ?? ''),
        icon: icon,
        displayOrder: sortOrder,
        active: active,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}

/// Maps the feature's browse filter onto the DAO's neutral criteria.
extension ProductFilterMapper on ProductFilter {
  ProductQuery toQuery({
    required String query,
    required int page,
    required int pageSize,
  }) {
    return ProductQuery(
      query: query,
      page: page,
      pageSize: pageSize,
      categoryId: categoryId,
      familyId: familyId,
      subCategory: subCategory,
      brand: brand,
      warehouseCode: warehouseCode,
      size: size,
      length: length,
      width: width,
      height: height,
      grade: grade,
      diameter: diameter,
      thickness: thickness,
      material: material,
      availableOnly: availableOnly,
      sort: switch (sortBy) {
        ProductSortBy.relevance => ProductQuerySort.relevance,
        ProductSortBy.nameAsc => ProductQuerySort.nameAsc,
        ProductSortBy.priceAsc => ProductQuerySort.priceAsc,
        ProductSortBy.priceDesc => ProductQuerySort.priceDesc,
        ProductSortBy.stockDesc => ProductQuerySort.stockDesc,
      },
    );
  }
}
