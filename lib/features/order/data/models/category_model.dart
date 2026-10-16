import 'package:steelforce/core/localization/localized_text.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/domain/entities/category.dart';

/// Wire/row DTO for a taxonomy node.
///
/// Both names travel on the *same* record in both directions — that is the
/// whole point of the single-source design. A feed that only sends `name` is
/// still valid: [_localized] falls back so an English-only category renders
/// rather than showing an empty label in Khmer.
class CategoryModel extends Category {
  const CategoryModel({
    required super.id,
    required super.code,
    required super.name,
    required super.displayOrder,
    super.parentId,
    super.description,
    super.icon,
    super.active,
    super.createdAt,
    super.updatedAt,
  });

  factory CategoryModel.fromJson(DataMap json) => CategoryModel(
        id: json['id'] as String,
        parentId: json['parentId'] as String?,
        // Falls back to the id so a malformed feed row is still traceable on
        // screen rather than rendering as a blank chip.
        code: (json['code'] as String?) ?? json['id'] as String,
        name: _localized(json['name'], json['nameKh']),
        description:
            _localizedOrNull(json['description'], json['descriptionKh']),
        icon: json['icon'] as String?,
        displayOrder: (json['sortOrder'] as num?)?.toInt() ??
            (json['displayOrder'] as num?)?.toInt() ??
            0,
        active: json['active'] as bool? ?? true,
        createdAt: _date(json['createdAt']),
        updatedAt: _date(json['updatedAt']),
      );

  factory CategoryModel.fromRow(DataMap row) => CategoryModel(
        id: row['id'] as String,
        parentId: row['parent_id'] as String?,
        code: (row['code'] as String?)?.trim().isNotEmpty == true
            ? row['code'] as String
            : row['id'] as String,
        name: _localized(row['name'], row['name_kh']),
        description:
            _localizedOrNull(row['description'], row['description_kh']),
        icon: row['icon'] as String?,
        displayOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
        active: _bool(row['active']),
        createdAt: _date(row['created_at']),
        updatedAt: _date(row['updated_at']),
      );

  DataMap toRow() => {
        'id': id,
        'parent_id': parentId,
        'code': code,
        'name': name.en,
        'name_kh': name.km,
        'description': description?.en,
        'description_kh': description?.km,
        'icon': icon,
        'sort_order': displayOrder,
        'active': active,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  static LocalizedText _localized(Object? en, Object? km) => LocalizedText(
        en: (en as String?) ?? '',
        km: (km as String?) ?? '',
      );

  static LocalizedText? _localizedOrNull(Object? en, Object? km) {
    final text = _localized(en, km);
    return text.isEmpty ? null : text;
  }

  /// SQLite has no boolean; drift stores 0/1, and a JSON feed sends a real
  /// bool. Accept both rather than assuming which caller you got.
  static bool _bool(Object? value) => switch (value) {
        bool b => b,
        num n => n != 0,
        String s => s == '1' || s.toLowerCase() == 'true',
        _ => true,
      };

  static DateTime? _date(Object? value) => switch (value) {
        DateTime d => d,
        String s => DateTime.tryParse(s),
        // Drift hands back epoch seconds for a DateTimeColumn.
        int i => DateTime.fromMillisecondsSinceEpoch(i * 1000, isUtc: true),
        _ => null,
      };
}
