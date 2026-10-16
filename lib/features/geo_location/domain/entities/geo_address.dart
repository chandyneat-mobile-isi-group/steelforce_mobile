import 'package:equatable/equatable.dart';
import 'package:steelforce/core/localization/localized_text.dart';
import 'package:steelforce/features/geo_location/domain/entities/geo_unit.dart';

/// Why a selected address is not submittable.
enum GeoAddressError {
  /// A required level has no selection.
  missingProvince,
  missingDistrict,
  missingCommune,
  missingVillage,

  /// A child does not belong to the parent above it. Only reachable through a
  /// bad payload or a stale draft — the cascade cannot produce it — which is
  /// exactly why it is checked rather than assumed away.
  brokenHierarchy,

  /// A commune was selected but Cambodia Post has no code for it. Not fatal on
  /// its own: [GeoAddress.postalCode] falls back to a manually entered value.
  postalCodeUnavailable;

  String get messageKey => switch (this) {
        GeoAddressError.missingProvince => 'geo.error.province_required',
        GeoAddressError.missingDistrict => 'geo.error.district_required',
        GeoAddressError.missingCommune => 'geo.error.commune_required',
        GeoAddressError.missingVillage => 'geo.error.village_required',
        GeoAddressError.brokenHierarchy => 'geo.error.broken_hierarchy',
        GeoAddressError.postalCodeUnavailable => 'geo.error.postal_unavailable',
      };
}

/// Which levels a given form insists on. Village is optional in most forms and
/// required in a delivery address, which is the §10 requirement.
class GeoAddressRequirement extends Equatable {
  const GeoAddressRequirement({
    this.province = true,
    this.district = true,
    this.commune = true,
    this.village = false,
    this.postalCode = true,
  });

  /// Everything down to commune, postal code derived. The default for
  /// depot and business-partner registration.
  static const standard = GeoAddressRequirement();

  /// Village required too — a truck has to find the door.
  static const delivery = GeoAddressRequirement(village: true);

  /// Nothing required; used where an address is a filter, not a record.
  static const optional = GeoAddressRequirement(
    province: false,
    district: false,
    commune: false,
    postalCode: false,
  );

  final bool province;
  final bool district;
  final bool commune;
  final bool village;
  final bool postalCode;

  @override
  List<Object?> get props => [province, district, commune, village, postalCode];
}

/// A complete or partial administrative address.
///
/// Immutable, value-equal, and the single thing a host form binds to. A form
/// stores this one object instead of five loose fields, which is what stops
/// the cascade logic from being reimplemented per screen (§9).
class GeoAddress extends Equatable {
  const GeoAddress({
    this.province,
    this.district,
    this.commune,
    this.village,
    this.manualPostalCode,
  });

  static const empty = GeoAddress();

  final GeoUnit? province;
  final GeoUnit? district;
  final GeoUnit? commune;
  final GeoUnit? village;

  /// Typed by the rep, and **only** consulted when the commune carries no code
  /// of its own. Kept separate from the derived value so that re-selecting a
  /// commune that does have a code cannot leave a stale manual entry in place.
  final String? manualPostalCode;

  /// The effective postal code: the commune's, else the manual fallback.
  ///
  /// Deriving rather than storing is what guarantees the §8 reset. There is no
  /// postal-code field to forget to clear — change the commune and this
  /// re-reads from the new one on the next access.
  String? get postalCode {
    final derived = commune?.postalCode;
    if (derived != null && derived.isNotEmpty) return derived;
    final manual = manualPostalCode?.trim();
    return (manual == null || manual.isEmpty) ? null : manual;
  }

  /// True when the code shown to the rep came from the gazetteer, which is when
  /// the field renders read-only (§2).
  bool get isPostalCodeDerived => (commune?.postalCode ?? '').isNotEmpty;

  /// True when a commune is selected but has no code — the case that must
  /// unlock the field rather than submit a blank or a guess.
  bool get needsManualPostalCode =>
      commune != null && (commune!.postalCode ?? '').isEmpty;

  GeoUnit? unitAt(GeoLevel level) => switch (level) {
        GeoLevel.province => province,
        GeoLevel.district => district,
        GeoLevel.commune => commune,
        GeoLevel.village => village,
      };

  /// Returns a copy with [level] set to [unit] **and every deeper level
  /// cleared** — the §8 rule, implemented once.
  ///
  /// The manual postal code is cleared alongside a commune change for the same
  /// reason the child selections are: it described the old commune.
  GeoAddress select(GeoLevel level, GeoUnit? unit) {
    return GeoAddress(
      province: level == GeoLevel.province ? unit : province,
      district: level.index < GeoLevel.district.index
          ? null
          : (level == GeoLevel.district ? unit : district),
      commune: level.index < GeoLevel.commune.index
          ? null
          : (level == GeoLevel.commune ? unit : commune),
      village: level.index < GeoLevel.village.index
          ? null
          : (level == GeoLevel.village ? unit : village),
      manualPostalCode:
          level.index <= GeoLevel.commune.index ? null : manualPostalCode,
    );
  }

  GeoAddress withManualPostalCode(String? value) => GeoAddress(
        province: province,
        district: district,
        commune: commune,
        village: village,
        manualPostalCode: value,
      );

  /// Structural check that each selected level really belongs to its parent
  /// (§14). Independent of how the selection was made.
  bool get isHierarchyIntact {
    if (district != null &&
        (province == null || !district!.isChildOf(province!.code))) {
      return false;
    }
    if (commune != null &&
        (district == null || !commune!.isChildOf(district!.code))) {
      return false;
    }
    if (village != null &&
        (commune == null || !village!.isChildOf(commune!.code))) {
      return false;
    }
    return true;
  }

  /// Every reason this address cannot be submitted under [requirement].
  ///
  /// Returns all of them rather than the first, so a form can mark three
  /// fields at once instead of making the rep submit three times to discover
  /// three problems.
  List<GeoAddressError> validate([
    GeoAddressRequirement requirement = GeoAddressRequirement.standard,
  ]) {
    final errors = <GeoAddressError>[];
    if (requirement.province && province == null) {
      errors.add(GeoAddressError.missingProvince);
    }
    if (requirement.district && district == null) {
      errors.add(GeoAddressError.missingDistrict);
    }
    if (requirement.commune && commune == null) {
      errors.add(GeoAddressError.missingCommune);
    }
    if (requirement.village && village == null) {
      errors.add(GeoAddressError.missingVillage);
    }
    if (!isHierarchyIntact) errors.add(GeoAddressError.brokenHierarchy);
    if (requirement.postalCode && commune != null && postalCode == null) {
      errors.add(GeoAddressError.postalCodeUnavailable);
    }
    return errors;
  }

  bool isValid([
    GeoAddressRequirement requirement = GeoAddressRequirement.standard,
  ]) =>
      validate(requirement).isEmpty;

  /// The codes to submit (§15). Names are deliberately absent — they are
  /// display data, and sending a localised string as a key is how a form ends
  /// up unmatchable when the rep switches language.
  Map<String, String?> toCodeMap() => {
        'provinceCode': province?.code,
        'districtCode': district?.code,
        'communeCode': commune?.code,
        'villageCode': village?.code,
        'postalCode': postalCode,
      };

  /// The address written out, deepest-first, the way a Cambodian address is
  /// read: `Phum Ou Thum, Khum Banteay Neang, Srok Mongkol Borei, Khaet
  /// Banteay Meanchey`.
  ///
  /// This is what the SAP `street` field carries the commune and village in —
  /// SAP's BP structure has fields for city, district and postal code only, so
  /// composing them here is how those two levels survive submission at all.
  /// See `docs/features/geo-location/api.md`.
  String format(String languageCode, {bool includeUnitWords = true}) {
    final parts = <String>[];
    for (final unit in [village, commune, district, province]) {
      if (unit == null) continue;
      final name = unit.name.resolve(languageCode);
      parts.add(
          includeUnitWords ? '${_unitWord(unit, languageCode)}$name' : name);
    }
    return parts.join(languageCode == 'km' ? ' ' : ', ');
  }

  /// Khmer writes the unit word joined to the name (`ភូមិអូរធំ`); English
  /// transliteration separates it (`Phum Ou Thum`).
  String _unitWord(GeoUnit unit, String languageCode) {
    if (languageCode != 'km') return '${unit.unit} ';
    return switch (unit.level) {
      GeoLevel.province => unit.unit == 'Capital' ? 'រាជធានី' : 'ខេត្ត',
      GeoLevel.district => switch (unit.unit) {
          'Khan' => 'ខណ្ឌ',
          'Municipality' => 'ក្រុង',
          _ => 'ស្រុក',
        },
      GeoLevel.commune => unit.unit == 'Sangkat' ? 'សង្កាត់' : 'ឃុំ',
      GeoLevel.village => 'ភូមិ',
    };
  }

  /// Both languages of [format], for storing on a record that will be read in
  /// either.
  LocalizedText get formatted =>
      LocalizedText(en: format('en'), km: format('km'));

  @override
  List<Object?> get props =>
      [province, district, commune, village, manualPostalCode];
}
