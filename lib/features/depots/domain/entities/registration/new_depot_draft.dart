import 'package:equatable/equatable.dart';
import 'package:steelforce/features/depots/domain/entities/registration/depot_draft_contact.dart';
import 'package:steelforce/features/depots/domain/entities/registration/depot_draft_sales_area.dart';
import 'package:steelforce/features/depots/domain/entities/registration/depot_draft_suppliers.dart';
import 'package:steelforce/features/depots/domain/entities/registration/mobile_depot_kind.dart';

/// A new depot or non-depot as the rep entered it, ready for
/// `POST /api/v1/mobile/depots`.
///
/// Field names follow the SAP depot, as the backend's `DepotDraftInput` does.
/// Only the server decides what is valid; the rules repeated in the doc
/// comments are there so the form can say so before a round trip.
///
/// Not here on purpose: status, source, customer number, postal code and
/// country. The server sets each of them and refuses none of them silently —
/// it simply never binds them.
class NewDepotDraft extends Equatable {
  const NewDepotDraft({
    required this.id,
    required this.nameEn,
    required this.telephone,
    required this.address,
    this.kind = MobileDepotKind.depot,
    this.depots = const [],
    this.nameKh,
    this.searchTerm1,
    this.searchTerm2,
    this.mobilePhone,
    this.faxNumber,
    this.email,
    this.location,
    this.contacts = const [],
    this.salesAreas = const [],
    this.creditLimit,
    this.creditTermDays,
    this.remarks,
    this.suppliers,
  });

  /// Client-generated v4 UUID, minted once per draft and reused on every
  /// resend: the server answers a resend with the saved draft (CD-BR15), so a
  /// lost response never becomes a second depot.
  final String id;

  /// `depotType`: what step 1 picked.
  final MobileDepotKind kind;

  /// A non-depot's supplying depots: 1-20 SAP customer numbers. Not sent for
  /// a depot.
  final List<String> depots;

  /// Required, 1-120 characters.
  final String nameEn;
  final String? nameKh;

  /// SAP search terms, ≤ 20 characters each.
  final String? searchTerm1;
  final String? searchTerm2;

  /// Required. A local `012 345 678` is stored by the server as `+85512345678`.
  final String telephone;
  final String? mobilePhone;
  final String? faxNumber;
  final String? email;

  final DepotDraftAddress address;

  /// Null when the rep captured no location — never a `0,0` placeholder.
  final DepotDraftLocation? location;

  /// 0-10, in display order; at most one primary.
  final List<DepotDraftContact> contacts;

  /// 1-10; sales org + distribution channel + division unique.
  final List<DepotDraftSalesArea> salesAreas;

  /// ≥ 0, two decimals. Null lets the server apply its default (0).
  final double? creditLimit;

  /// 0-365 days. Null lets the server apply its default (14). Independent of
  /// the sales area's payment terms code (backend CD-A9).
  final int? creditTermDays;

  /// ≤ 1000 characters.
  final String? remarks;

  /// Null sends no suppliers at all; see [DepotDraftSuppliers].
  final DepotDraftSuppliers? suppliers;

  @override
  List<Object?> get props => [
        id,
        kind,
        depots,
        nameEn,
        nameKh,
        searchTerm1,
        searchTerm2,
        telephone,
        mobilePhone,
        faxNumber,
        email,
        address,
        location,
        contacts,
        salesAreas,
        creditLimit,
        creditTermDays,
        remarks,
        suppliers,
      ];
}

/// Gazetteer (NCDD) codes: province is required, and each lower level needs
/// the one above. The app's bundled `kh_geo_seed_v1.json` is the same dataset
/// the server validates against.
class DepotDraftAddress extends Equatable {
  const DepotDraftAddress({
    required this.provinceCode,
    this.districtCode,
    this.communeCode,
    this.villageCode,
    this.street,
  });

  final String provinceCode;
  final String? districtCode;
  final String? communeCode;
  final String? villageCode;

  /// House number and street, ≤ 250 characters.
  final String? street;

  @override
  List<Object?> get props =>
      [provinceCode, districtCode, communeCode, villageCode, street];
}

/// A captured position. Both coordinates or no location at all.
class DepotDraftLocation extends Equatable {
  const DepotDraftLocation({
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
  });

  final double latitude;
  final double longitude;

  /// The phone's reported accuracy, 0-10000 m; null when placed on a map.
  final double? accuracyMeters;

  /// What the server accepts: inside the globe and not the `0,0` that a
  /// failed fix reports.
  bool get isPlausible =>
      latitude.abs() <= 90 &&
      longitude.abs() <= 180 &&
      !(latitude == 0 && longitude == 0);

  @override
  List<Object?> get props => [latitude, longitude, accuracyMeters];
}
