import 'package:steelforce/core/practice/practice_ids.dart';
import 'package:steelforce/features/depots/data/models/bp_depot_form_data.dart';
import 'package:steelforce/features/depots/domain/entities/business_partner_request.dart';
import 'package:steelforce/features/depots/domain/entities/depot.dart';
import 'package:steelforce/features/depots/domain/entities/depot_activity.dart';
import 'package:steelforce/features/depots/domain/entities/depot_contact.dart';
import 'package:steelforce/features/depots/domain/entities/depot_note.dart';
import 'package:steelforce/features/depots/domain/entities/depot_status.dart';

/// Everything a practice run of the depot screens reads and writes.
///
/// One instance per practice world, shared by every depot stand-in, so the
/// shop a rep registers in the wizard is the one the list shows first, the
/// detail screen opens and the stop screen profiles. Memory only: ending the
/// session drops it with the scope, and nothing here is ever persisted.
class PracticeDepotStore {
  PracticeDepotStore({DateTime Function()? clock})
      : _clock = clock ?? DateTime.now {
    _demo = practiceDemoDepot(_clock());
  }

  final DateTime Function() _clock;
  late final Depot _demo;

  /// Registered during this run, newest first.
  final List<Depot> _created = [];
  final Map<String, List<DepotNote>> _notes = {};
  final Map<String, List<DepotActivity>> _activities = {};
  final Set<String> _favorites = {};
  final List<String> _recent = [];

  /// The wizard's saved form, if the rep has one in this run.
  BpDepotDraft? draft;

  int _sequence = 0;

  DateTime now() => _clock();

  /// The practice directory: depots registered in this run, newest first,
  /// then the ready-made demo depot.
  List<Depot> get depots => List.unmodifiable([..._created, _demo]);

  Depot? byId(String id) {
    for (final depot in depots) {
      if (depot.id == id) return depot;
    }
    return null;
  }

  /// Files [request] as a newly registered depot and returns it.
  ///
  /// Mirrors what the real flow leads to: a field registration awaiting HQ,
  /// with no SAP number yet — which is also why it cannot be added to a visit
  /// (`adHocOutlet` is null without a depot code).
  Depot register(BusinessPartnerRequest request) {
    _sequence++;
    final at = _clock();
    final nameEn = request.name1.trim();
    final nameKh = request.name3.trim();
    final depot = Depot(
      id: '${PracticeIds.createdDepotPrefix}$_sequence',
      depotCode: 'PRACTICE-NEW-$_sequence',
      shopName: nameEn.isNotEmpty ? nameEn : nameKh,
      enName: nameEn.isEmpty ? null : nameEn,
      khName: nameKh.isEmpty ? null : nameKh,
      ownerName: _ownerFrom(request.coName),
      phone: request.mobilePhone,
      address: [request.houseNo, request.street]
          .where((p) => p.trim().isNotEmpty)
          .join(', '),
      province: _demoProvince,
      district: _demoDistrict,
      territory: _demoProvince,
      latitude: double.tryParse(request.latitude) ?? 0,
      longitude: double.tryParse(request.longitude) ?? 0,
      creditLimit: 0,
      status: DepotStatus.pendingApproval,
      assignedRepId: request.personnelNumber,
      assignedRepName: '',
      updatedAt: at,
      createdAt: at,
      salesOrg: request.salesOrg,
      division: request.division,
      distributionChannel: request.distributionChannel,
      depotGroup: request.depotGroup,
      priceGroup: request.priceGroup.isEmpty ? null : request.priceGroup,
      currency: request.currency.isEmpty ? 'USD' : request.currency,
    );
    _created.insert(0, depot);
    return depot;
  }

  /// Files a depot another stand-in builds, numbered like [register]'s.
  Depot file(Depot Function(int sequence, DateTime at) build) {
    final depot = build(++_sequence, _clock());
    _created.insert(0, depot);
    return depot;
  }

  List<DepotNote> notesFor(String depotId) =>
      List.unmodifiable(_notes[depotId] ?? const []);

  void addNote(String depotId, String body) {
    final at = _clock();
    (_notes[depotId] ??= []).insert(
      0,
      DepotNote(
        id: '$depotId-NOTE-${at.microsecondsSinceEpoch}',
        depotId: depotId,
        body: body,
        createdAt: at,
      ),
    );
  }

  List<DepotActivity> activitiesFor(String depotId) =>
      List.unmodifiable(_activities[depotId] ?? const []);

  void addActivity(DepotActivity activity) =>
      (_activities[activity.depotId] ??= []).insert(0, activity);

  void toggleFavorite(String depotId) {
    if (!_favorites.remove(depotId)) _favorites.add(depotId);
  }

  List<Depot> get favorites =>
      depots.where((d) => _favorites.contains(d.id)).toList(growable: false);

  void recordViewed(String depotId) {
    _recent
      ..remove(depotId)
      ..insert(0, depotId);
  }

  List<Depot> get recent => [
        for (final id in _recent)
          if (byId(id) case final depot?) depot,
      ];

  static String _ownerFrom(String coName) {
    // `coName` is "Name-Role"; the person is the part before the role.
    final dash = coName.lastIndexOf('-');
    return (dash > 0 ? coName.substring(0, dash) : coName).trim();
  }
}

const _demoProvince = 'Phnom Penh';
const _demoDistrict = 'Chamkar Mon';

/// Demo contact details. Deliberately not a plausible live number: a rep who
/// taps "call" during a lesson must not ring a stranger.
const practiceDemoPhone = '+85512000000';
const practiceDemoOwner = 'Sokha Chan';
const practiceDemoAddress = 'No. 25, St. 271, Sangkat Tonle Basak';
const practiceDemoLatitude = 11.5564;
const practiceDemoLongitude = 104.9282;

/// The ready-made demo depot every lesson can use ([PracticeIds.depotId]).
///
/// Active, so a quotation can be raised against it. No `sapDepotId`, so it
/// is never offered to the ad hoc visit endpoint, which is keyed on one.
Depot practiceDemoDepot(DateTime now) => Depot(
      id: PracticeIds.depotId,
      depotCode: PracticeIds.depotCode,
      shopName: PracticeIds.depotNameEn,
      enName: PracticeIds.depotNameEn,
      khName: PracticeIds.depotNameKh,
      ownerName: practiceDemoOwner,
      phone: practiceDemoPhone,
      address: practiceDemoAddress,
      province: _demoProvince,
      district: _demoDistrict,
      territory: _demoProvince,
      latitude: practiceDemoLatitude,
      longitude: practiceDemoLongitude,
      creditLimit: 5000,
      creditBalance: 1250,
      status: DepotStatus.active,
      assignedRepId: '',
      assignedRepName: '',
      updatedAt: now,
      createdAt: now,
      contacts: const [
        DepotContact(
          id: '${PracticeIds.depotId}-contact-1',
          name: practiceDemoOwner,
          role: 'Owner',
          phone: practiceDemoPhone,
        ),
      ],
      salesOrg: '0001',
      division: '10',
      distributionChannel: '10',
      depotGroup: '01',
      priceGroup: '11',
      currency: 'USD',
    );
