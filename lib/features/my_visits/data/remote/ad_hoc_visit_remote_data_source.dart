import 'package:steelforce/features/my_visits/data/models/ad_hoc_visit_response.dart';

/// `POST /api/v1/mobile/visits/ad-hoc` — add a depot the Call Plan missed.
abstract interface class AdHocVisitRemoteDataSource {
  /// Throws `ApiException` on anything the server refuses, so the repository
  /// can branch on `ApiError.code`.
  ///
  /// [clientRequestId] must be the **same** value on every retry of the same
  /// user tap; a fresh id is a fresh visit.
  ///
  /// [sk] is the depot's **SAP code** — not its id, and not its display code.
  Future<AdHocVisitResponse> create({
    required String sk,
    required String clientRequestId,
  });
}
