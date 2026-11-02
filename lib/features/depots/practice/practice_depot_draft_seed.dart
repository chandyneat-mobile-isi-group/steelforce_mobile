import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:steelforce/core/localization/localized_text.dart';
import 'package:steelforce/features/depots/data/models/bp_depot_form_data.dart';
import 'package:steelforce/features/depots/practice/practice_depot_store.dart';
import 'package:steelforce/features/geo_location/domain/entities/geo_address.dart';
import 'package:steelforce/features/geo_location/domain/entities/geo_unit.dart';
import 'package:steelforce/core/assets/app_assets.dart';

/// The registration form a practice run opens with.
///
/// Every step is filled with values that pass `validateStep`. The identity
/// names are added by the form when the depot practice lesson opens, so they
/// appear in the live fields and remain confined to the practice draft.
///
/// The codes are real, so every dropdown shows a selected option rather than a
/// code it does not know: SAP codes from the built-in lists the form falls back
/// to (`SapMasterData`, `SapBpConst`), and the address from the bundled NCDD
/// gazetteer (`assets/geo/kh_geo_seed_v1.json`) — Phnom Penh › Chamkar Mon ›
/// Tonle Basak › Phum 1, postal code 120101. The GPS fix sits inside that
/// commune, well within the Cambodia bounds `GeoFix.isInsideCambodia` checks.
///
/// A fresh instance on every call: the draft is mutable and the wizard writes
/// straight onto it.
BpDepotDraft practiceSeedDraft({
  required DateTime now,
  List<BpAttachment> photos = const [],
}) {
  return BpDepotDraft(
    grouping: 'Z001', // Local Depot
    title: '0003', // Company
    street: 'St. 271',
    houseNumber: '25',
    cityCode: _province.code,
    districtCode: _district.code,
    communeCode: _commune.code,
    villageCode: _village.code,
    postalCode: _commune.postalCode!,
    geoAddress: const GeoAddress(
      province: _province,
      district: _district,
      commune: _commune,
      village: _village,
    ),
    geoFix: GeoFix(
      latitude: practiceDemoLatitude,
      longitude: practiceDemoLongitude,
      accuracyMeters: 8,
      capturedAt: now.toUtc(),
    ),
    mobilePhone: practiceDemoPhone,
    telephoneSameAsMobile: true,
    contactPersonName: practiceDemoOwner,
    contactPersonRole: 'owner',
    salesOrg: SapBpConst.salesOrg,
    salesOffice: SapBpConst.salesOffice,
    salesGroupCode: SapBpConst.salesGroup,
    distributionChannel: '10', // End-User
    divisionCode: '10', // ISI Steel
    depotGroup: '01', // End-User -> price group 11
    priceGroup: '11',
    deliveryPriority: '02', // Normal
    shippingCondition: '01', // ISI Services
    // Cash on delivery: a credit term would route the lesson through credit
    // approval wording that is not what it is teaching.
    paymentTerm: 'TCOD',
    taxClass: '0', // Non VAT — so no VAT certificate is required
    currency: 'USD',
    salesSurvey: DepotSalesSurvey(
      productLines: {SurveyProductLine.steel},
      steelTypes: {SurveySteelType.rebar},
      steelMonthlySales: '12000',
      shareToDepots: '60',
      shareToEndUsers: '40',
    ),
    attachments: [
      for (final photo in photos) photo.copyWith(),
    ],
  );
}

const _province = GeoUnit(
  level: GeoLevel.province,
  code: '12',
  name: LocalizedText(en: 'Phnom Penh', km: 'ភ្នំពេញ'),
  unit: 'Capital',
);
const _district = GeoUnit(
  level: GeoLevel.district,
  code: '1201',
  name: LocalizedText(en: 'Chamkar Mon', km: 'ចំការមន'),
  unit: 'Khan',
  parentCode: '12',
);
const _commune = GeoUnit(
  level: GeoLevel.commune,
  code: '120101',
  name: LocalizedText(en: 'Tonle Basak', km: 'ទន្លេបាសាក់'),
  unit: 'Sangkat',
  parentCode: '1201',
  postalCode: '120101',
);
const _village = GeoUnit(
  level: GeoLevel.village,
  code: '12010101',
  name: LocalizedText(en: 'Phum 1', km: 'ភូមិ ១'),
  unit: 'Village',
  parentCode: '120101',
);

/// Demo evidence photographs for the documents step.
///
/// ## Why seed them
///
/// The documents step blocks `Next` until the storefront, inside-store and ID
/// card slots hold a photograph. A lesson on an emulator, or on a handset whose
/// camera permission the rep declines, could then never be finished — and the
/// step's point is "this is where the photos go", which a filled slot shows as
/// well as an empty one. The rep can still retake any of them.
///
/// The images are the synthetic stand-ins the simulator camera already uses
/// (`assets/mock/camera/`), copied to a private temp directory because a draft
/// attachment is a file path. [dispose] deletes the directory; the practice
/// module calls it when the session ends.
///
/// On the web there is no file system to copy to, so no photographs are
/// seeded and the rep captures them as in the real flow. Any other failure
/// degrades the same way — seeding is a convenience, never a reason the form
/// will not open.
class PracticeDemoPhotos {
  PracticeDemoPhotos({
    Future<Directory> Function()? baseDirectory,
    Future<ByteData> Function(String asset)? loadAsset,
    bool? isWeb,
  })  : _baseDirectory = baseDirectory ?? getTemporaryDirectory,
        _loadAsset = loadAsset ?? rootBundle.load,
        _isWeb = isWeb ?? kIsWeb;

  final Future<Directory> Function() _baseDirectory;
  final Future<ByteData> Function(String asset) _loadAsset;
  final bool _isWeb;

  /// Slot kind -> bundled image.
  static const Map<String, String> assets = {
    'outlet_front': AppDataAssets.mockStorefrontPhoto,
    'outlet_inside': AppDataAssets.mockInsideStorePhoto,
    'id_card': AppDataAssets.mockIdCardPhoto,
  };

  Directory? _directory;
  Future<List<BpAttachment>>? _photos;

  /// The seeded attachments, copied once per session.
  Future<List<BpAttachment>> attachments() => _photos ??= _copy();

  Future<List<BpAttachment>> _copy() async {
    if (_isWeb) return const [];
    try {
      final base = await _baseDirectory();
      final directory = await base.createTemp('practice_depot_');
      _directory = directory;
      final capturedAt = DateTime.now().toUtc();
      final photos = <BpAttachment>[];
      for (final MapEntry(key: kind, value: asset) in assets.entries) {
        final bytes = await _loadAsset(asset);
        final file = File('${directory.path}/$kind.png');
        await file.writeAsBytes(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
          flush: true,
        );
        photos.add(
          BpAttachment(
            kind: kind,
            localPath: file.path,
            capturedAt: capturedAt,
          ),
        );
      }
      return List.unmodifiable(photos);
    } on Object catch (e) {
      debugPrint('PracticeDemoPhotos: not seeded — ${e.runtimeType}');
      return const [];
    }
  }

  /// Deletes the copied images. Safe to call more than once.
  Future<void> dispose() async {
    final directory = _directory;
    _directory = null;
    _photos = null;
    if (directory != null && directory.existsSync()) {
      await directory.delete(recursive: true);
    }
  }
}
