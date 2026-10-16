import 'package:steelforce/core/error/exceptions.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/logging/debug_trace.dart';
import 'package:steelforce/core/network/connectivity/network_info.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/depots/data/datasources/business_partner_remote_data_source.dart';
import 'package:steelforce/features/depots/data/local/bp_draft_cache.dart';
import 'package:steelforce/features/depots/data/local/depot_reference_cache.dart';
import 'package:steelforce/features/depots/domain/entities/bp_depot_draft.dart';
import 'package:steelforce/features/depots/data/models/business_partner_request_model.dart';
import 'package:steelforce/features/depots/data/models/business_partner_response_model.dart';
import 'package:steelforce/features/depots/data/models/sap_reference_options.dart';
import 'package:steelforce/features/depots/data/remote/depot_datasources.dart'
    as legacy;
import 'package:steelforce/features/depots/domain/entities/business_partner_request.dart';
import 'package:steelforce/features/depots/domain/entities/business_partner_result.dart';
import 'package:steelforce/features/depots/domain/repositories/business_partner_repository.dart';

const _trace = DebugTrace('registration');

class BusinessPartnerRepositoryImpl implements BusinessPartnerRepository {
  const BusinessPartnerRepositoryImpl({
    required BusinessPartnerRemoteDataSource remote,
    required legacy.DepotRemoteDataSource references,
    required DepotReferenceCache referenceCache,
    required BpDraftCache draftCache,
    NetworkInfo? network,
  })  : _network = network,
        _remote = remote,
        _references = references,
        _referenceCache = referenceCache,
        _draftCache = draftCache;

  /// The single-write registration endpoint.
  final BusinessPartnerRemoteDataSource _remote;

  /// `GET /references` still lives on the older data source. Kept there rather
  /// than duplicated onto [_remote]: the catalogues are unrelated to the write
  /// and are also read by other screens.
  final legacy.DepotRemoteDataSource _references;

  final DepotReferenceCache _referenceCache;
  final BpDraftCache _draftCache;

  /// Lets an offline device go straight to its cached catalogues instead of
  /// waiting out a connect timeout. Optional so tests need not stub it; when
  /// absent the request is simply attempted.
  final NetworkInfo? _network;

  // ---------------------------------------------------------------------
  // Write
  // ---------------------------------------------------------------------

  @override
  ResultFuture<BusinessPartnerResult> createBusinessPartner(
    BusinessPartnerRequest request,
  ) =>
      _send(request.copyWith(commit: true, submitToSap: true));

  @override
  ResultFuture<BusinessPartnerResult> validateBusinessPartner(
    BusinessPartnerRequest request,
  ) =>
      // `submitToSap` stays true: the point of a dry run is to exercise the
      // SAP path. `Commit: false` is what makes it a dry run — with
      // `submitToSap: false` the middleware would park the record and answer
      // without asking SAP anything, which validates nothing.
      _send(request.copyWith(commit: false, submitToSap: true));

  ResultFuture<BusinessPartnerResult> _send(
    BusinessPartnerRequest request,
  ) async {
    // Refused here rather than at the data source so a queued replay is caught
    // too. A record without a sales area is accepted by the endpoint and then
    // cannot be delivered to SAP, so the rep would be told it worked and HQ
    // would find it stuck.
    final missing = request.missingForRegistration;
    if (missing.isNotEmpty) {
      _trace.fail('bp', 'blocked before send', {
        'missing': DebugTrace.names(missing),
      });
      return Failed(
        ServerFailure(
          message: 'Cannot register: ${missing.join(', ')} '
              '${missing.length == 1 ? 'is' : 'are'} missing.',
          statusCode: 422,
        ),
      );
    }

    // No network interface at all: refused before sending, so the outcome is
    // provably "never sent" and the offline queue may resend it automatically.
    // Without this a browser — which reports every transport failure alike —
    // would leave every offline submit for the rep to review by hand.
    final network = _network;
    if (network != null && !await network.isConnected) {
      _trace.warn('bp', 'not sent — offline', const {});
      return const Failed(NetworkFailure());
    }

    _trace.send('bp', request.commit ? 'POST commit' : 'POST dry-run', {
      'sales_area':
          '${request.salesOrg}/${request.distributionChannel}/${request.division}',
      'existing': request.depotNumber.isEmpty ? 'create' : 'extend',
    });

    try {
      final result = await _remote.createBusinessPartner(
        BusinessPartnerRequestModel.fromEntity(request),
      );

      // SAP's business rejection arrives as HTTP 200 with error rows. Mapped
      // to a Left so the bloc has one failure path, and carrying SAP's own
      // wording — the rep can act on "payment term T015 not defined for sales
      // organisation 0003" and cannot act on "submission failed".
      if (result.hasError) {
        _trace.fail('bp', 'rejected by SAP', {
          'messages': result.errors.length,
          'code': result.errors.first.code,
        });
        return Failed(
          ServerFailure(
            message: result.primaryMessage ?? 'SAP rejected the registration',
            statusCode: 422,
          ),
        );
      }

      // A missing depot number is NOT a failure.
      //
      // This endpoint returns `depotCode: null` with `sapStatus:
      // PENDING_HQ` for a record it has stored and will push to SAP after
      // approval. The earlier check required a number and so reported every
      // pending registration as failed — which sends the rep back to
      // re-enter a shop that is already on file, and hands HQ a duplicate.
      //
      // What is checked instead is whether the server gave us *any* handle on
      // the record. With no id, no number and no status there is nothing to
      // attach documents to and nothing to show the rep, and that genuinely
      // did fail.
      if (request.commit && !result.isAccepted) {
        _trace.fail('bp', 'response carried no usable record', {
          // The received field names, so a shape change is diagnosable from
          // one log line instead of a debugger session.
          // `result` is always a BusinessPartnerResponseModel here, so the
          // old `is` check only ever took this branch.
          'keys': DebugTrace.names(result.receivedKeys),
          'status': result.status.name,
        });
        return const Failed(
          ServerFailure(
            message: 'The server accepted the registration but returned no '
                'reference for it. Check the depot list before submitting '
                'again.',
            // 422, not 5xx. The call reached the server and the server
            // answered; a 5xx here would be classified downstream as a
            // gateway failure and reported to the rep as "held, will retry",
            // which is exactly the wrong advice when the record may exist.
            statusCode: 422,
          ),
        );
      }

      if (!request.commit) {
        _trace.ok('bp', 'dry-run passed', const {});
      } else if (result.isPendingApproval) {
        _trace.ok('bp', 'stored, awaiting HQ approval', {
          'record': DebugTrace.id(result.localId),
          'status': result.status.name,
        });
      } else {
        _trace.ok('bp', 'created in SAP', {
          'depot': DebugTrace.id(result.depotNumber),
          'record': DebugTrace.id(result.localId),
        });
      }
      return Success(result);
    } on NetworkException catch (e) {
      // Nothing reached SAP. Mapped to `NetworkFailure` so the caller can
      // requeue without a duplicate check.
      _trace.warn('bp', 'not sent — no connection', const {});
      return Failed(NetworkFailure(message: e.message));
    } on ServerException catch (e) {
      _trace.fail('bp', 'transport failed', {'status': e.statusCode});
      return Failed(
        ServerFailure(message: e.message, statusCode: e.statusCode),
      );
    }
  }

  // ---------------------------------------------------------------------
  // Reference catalogues
  // ---------------------------------------------------------------------

  @override
  Future<SapReferenceOptions> loadReferenceOptions({
    bool includeInactive = false,
  }) async {
    // Online-first: while there is a connection the catalogues come from the
    // API, and the cache below is only the offline fallback.
    final online = await _network?.isConnected ?? true;
    if (online) {
      try {
        final fetched = await _references.fetchRegistrationReferences(
          includeInactive: includeInactive,
        );
        if (!fetched.isEmpty) {
          await _referenceCache.write(
            fetched,
            includeInactive: includeInactive,
          );
          _trace.ok('refs', 'fetched', {
            'catalogues': fetched.catalogues.length,
          });
          return SapReferenceOptions(fetched);
        }
      } on Object catch (e) {
        // Swallowed on purpose. This method is contracted never to throw: the
        // registration form must open with no signal, and the fallbacks below
        // are strictly better than an error screen.
        _trace.warn('refs', 'fetch failed, falling back', {
          'error': e.runtimeType,
        });
      }
    }

    // Stale beats empty. A dropdown built from a week-old catalogue may offer
    // a code SAP has since retired; an empty one offers nothing and the rep
    // cannot register at all.
    final stale = _referenceCache.readStale(includeInactive: includeInactive);
    if (stale != null && !stale.isEmpty) {
      _trace.warn('refs', 'cache hit (stale)', {
        'at': _referenceCache
            .cachedAt(includeInactive: includeInactive)
            ?.toIso8601String(),
      });
      return SapReferenceOptions(stale);
    }

    _trace.warn('refs', 'built-in lists');
    return SapReferenceOptions.empty;
  }

  // ---------------------------------------------------------------------
  // Local form
  // ---------------------------------------------------------------------

  @override
  Future<BpDepotDraft?> loadDraft() => _draftCache.read();

  @override
  Future<void> saveDraft(BpDepotDraft draft) => _draftCache.write(draft);

  @override
  Future<void> clearDraft() => _draftCache.clear();
}
