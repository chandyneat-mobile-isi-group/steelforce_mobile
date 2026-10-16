import 'package:steelforce/core/session/session_manager.dart';
import 'package:steelforce/features/authentication/domain/repositories/auth_repository.dart';
import 'package:steelforce/features/depots/data/local/rep_sales_context_source.dart';
import 'package:steelforce/features/depots/domain/entities/bp_depot_draft.dart';
import 'package:steelforce/features/depots/domain/entities/rep_sales_context.dart';

/// Reads the rep from the session and the cached `GET /auth/me` profile.
///
/// The cached profile, not a network call: the form opens and submits from a
/// shop counter with no signal, and the profile written at sign-in carries the
/// same `employeeId`.
///
/// The sales organisation and office are left empty on purpose. The profile
/// does not carry them, and [BpDepotDraft.applyRepDefaults] fills an empty one
/// from the documented defaults (`SapBpConst`) — so the payload is unchanged,
/// but the app no longer pretends those defaults are the rep's own sales area.
class SessionRepSalesContextSource implements RepSalesContextSource {
  const SessionRepSalesContextSource({
    required AuthRepository auth,
    required SessionManager session,
  })  : _auth = auth,
        _session = session;

  final AuthRepository _auth;
  final SessionManager _session;

  @override
  Future<RepSalesContext?> current() async {
    final user = _session.currentUser;
    if (user == null) return null;

    final result = await _auth.cachedProfile();
    final profile = result.when(success: (p) => p, failure: (_) => null);
    if (profile == null) return null;

    // A profile cached for a different account is not this rep's identity.
    // Sign-out clears it, but a crash between clearing the session and
    // clearing the cache must not attribute this rep's shop to the last one.
    if (profile.id != user.id) return null;

    final personnelNumber = profile.employeeId.trim();
    // SAP `PERNR` is numeric; anything else is rejected on the push, so it is
    // treated as "no identity" here rather than sent.
    if (personnelNumber.isEmpty ||
        !RegExp(r'^[0-9]+$').hasMatch(personnelNumber)) {
      return null;
    }

    return RepSalesContext(
      salesOrganization: '',
      salesOrganizationName: '',
      salesOffice: '',
      salesOfficeName: '',
      salesEmployeeId: personnelNumber,
      salesEmployeeName: profile.fullName,
    );
  }
}
