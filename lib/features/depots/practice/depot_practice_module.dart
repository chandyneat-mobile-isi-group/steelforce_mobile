import 'package:get_it/get_it.dart';
import 'package:steelforce/core/practice/practice_session.dart';
import 'package:steelforce/features/depots/data/local/rep_sales_context_source.dart';
import 'package:steelforce/features/depots/domain/repositories/business_partner_repository.dart';
import 'package:steelforce/features/depots/domain/repositories/depot_document_repository.dart';
import 'package:steelforce/features/depots/domain/repositories/depot_draft_repository.dart';
import 'package:steelforce/features/depots/domain/repositories/depot_registration_outbox.dart';
import 'package:steelforce/features/depots/domain/repositories/depot_repository.dart';
import 'package:steelforce/features/depots/domain/repositories/depot_stop_information_repository.dart';
import 'package:steelforce/features/depots/domain/repositories/depot_sync_repository.dart';
import 'package:steelforce/features/depots/practice/practice_business_partner_repository.dart';
import 'package:steelforce/features/depots/practice/practice_depot_draft_repository.dart';
import 'package:steelforce/features/depots/practice/practice_depot_draft_seed.dart';
import 'package:steelforce/features/depots/practice/practice_depot_repository.dart';
import 'package:steelforce/features/depots/practice/practice_depot_side_repositories.dart';
import 'package:steelforce/features/depots/practice/practice_depot_store.dart';
import 'package:steelforce/features/depots/practice/practice_depot_sync_repository.dart';

/// Registers the depot feature's practice stand-ins into the practice scope.
///
/// Runs inside `PracticeSession.start`'s pushed scope. Every real
/// implementation is resolved **before** its stand-in is registered — after
/// that, `sl<T>()` answers with the stand-in. The caller then rebuilds the use
/// cases over them (`registerDepotUseCases`); the blocs are factories, so every
/// depot screen opened during practice gets the stand-ins with no change to
/// the screen.
///
/// Every path a lesson's depot screens write through is covered:
///
/// | Write | Real home | Practice |
/// |---|---|---|
/// | favourite, recently viewed, note, activity (incl. the detail screen's edit) | Drift via [DepotRepository] | [PracticeDepotStore] |
/// | directory pull, detail hydrate, by-code lookup | API + Drift via [DepotSyncRepository] | no-op |
/// | registration create + evidence | API via [DepotDraftRepository] | [PracticeDepotStore] |
/// | legacy registration create / dry run | API via [BusinessPartnerRepository] | [PracticeDepotStore] |
/// | wizard draft | encrypted Hive `BpDraftCache` | [PracticeDepotStore] |
/// | evidence upload | API via [DepotDocumentRepository] | no-op |
/// | offline registration queue | Drift via [DepotRegistrationOutbox] | no-op |
///
/// Deliberately left real: the master-data repository (read-only lookups no
/// lesson reaches) and the reference catalogues behind the form's dropdowns,
/// which [PracticeBusinessPartnerRepository] reads through.
void registerDepotPracticeStandIns(GetIt sl, PracticeWorld world) {
  final realDepots = sl<DepotRepository>();
  final realSync = sl<DepotSyncRepository>();
  final realRegistrations = sl<BusinessPartnerRepository>();
  final realDrafts = sl<DepotDraftRepository>();
  final realDocuments = sl<DepotDocumentRepository>();
  final realOutbox = sl<DepotRegistrationOutbox>();
  final realStopInformation = sl<DepotStopInformationRepository>();
  final realRepSource = sl<RepSalesContextSource>();

  final store = PracticeDepotStore();
  final photos = PracticeDemoPhotos();
  world.onClose(photos.dispose);

  sl
    ..registerLazySingleton<DepotRepository>(
      () => PracticeDepotRepository(
        real: realDepots,
        world: world,
        store: store,
      ),
    )
    ..registerLazySingleton<DepotSyncRepository>(
      () => PracticeDepotSyncRepository(
        real: realSync,
        world: world,
        store: store,
      ),
    )
    ..registerLazySingleton<BusinessPartnerRepository>(
      () => PracticeBusinessPartnerRepository(
        real: realRegistrations,
        world: world,
        store: store,
        photos: photos,
      ),
    )
    ..registerLazySingleton<DepotDraftRepository>(
      () => PracticeDepotDraftRepository(
        real: realDrafts,
        world: world,
        store: store,
      ),
    )
    ..registerLazySingleton<DepotDocumentRepository>(
      () => PracticeDepotDocumentRepository(real: realDocuments, world: world),
    )
    ..registerLazySingleton<DepotRegistrationOutbox>(
      () => PracticeDepotRegistrationOutbox(real: realOutbox, world: world),
    )
    ..registerLazySingleton<DepotStopInformationRepository>(
      () => PracticeDepotStopInformationRepository(
        real: realStopInformation,
        world: world,
        store: store,
      ),
    )
    ..registerLazySingleton<RepSalesContextSource>(
      () => PracticeRepSalesContextSource(real: realRepSource, world: world),
    );
}
