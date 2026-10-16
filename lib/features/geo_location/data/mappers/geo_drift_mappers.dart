import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/localization/localized_text.dart';
import 'package:steelforce/features/geo_location/domain/entities/geo_unit.dart';

/// Drift rows → domain entities (ADR-003: a repository returns entities, never
/// rows). Four one-line mappers rather than one generic one, because the row
/// types share no supertype and the levels differ in exactly the fields that
/// matter — only a commune has a postal code, only a province has no parent.
extension GeoProvinceRowX on GeoProvinceRow {
  GeoUnit toEntity() => GeoUnit(
        level: GeoLevel.province,
        code: code,
        name: LocalizedText(en: nameEn, km: nameKm),
        unit: unit,
      );
}

extension GeoDistrictRowX on GeoDistrictRow {
  GeoUnit toEntity() => GeoUnit(
        level: GeoLevel.district,
        code: code,
        name: LocalizedText(en: nameEn, km: nameKm),
        unit: unit,
        parentCode: provinceCode,
      );
}

extension GeoCommuneRowX on GeoCommuneRow {
  GeoUnit toEntity() => GeoUnit(
        level: GeoLevel.commune,
        code: code,
        name: LocalizedText(en: nameEn, km: nameKm),
        unit: unit,
        parentCode: districtCode,
        postalCode: postalCode,
      );
}

extension GeoVillageRowX on GeoVillageRow {
  GeoUnit toEntity() => GeoUnit(
        level: GeoLevel.village,
        code: code,
        name: LocalizedText(en: nameEn, km: nameKm),
        // Villages have no administrative variants — every one of the 14,372
        // is a ភូមិ. Hardcoded rather than stored 14,372 times.
        unit: 'Village',
        parentCode: communeCode,
      );
}
