import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/depots/domain/entities/bp_depot_draft.dart';
import 'package:steelforce/features/depots/data/models/sap_reference_options.dart';
import 'package:steelforce/features/depots/domain/entities/business_partner_request.dart';
import 'package:steelforce/features/depots/domain/entities/business_partner_result.dart';

/// The one door to `/api/v1/mobile/depots/business-partner`.
///
/// ## Why this replaced the server-draft protocol
///
/// Registration used to run over three calls — `POST /draft` to obtain an id,
/// `POST /update` to patch each step, `POST /submit` to finish. That shape had
/// one fatal property in the field: the rep could not *start* the form without
/// a connection, because there was no id to hang edits on. A rep standing in a
/// shop with no signal is the normal case, not the edge case.
///
/// The single write removes the id, so the wizard is now pure local state until
/// the moment of submit. What was lost with the server draft — resuming a
/// half-filled form on another handset — is covered locally by [saveDraft] and
/// [loadDraft], which is where it belonged anyway: the rep who filled a form in
/// is the rep who finishes it.
///
/// Deliberately separate from `DepotSyncRepository`, which owns reads of the
/// approved depot directory. This one only writes.
///
/// The three local-form methods live here rather than on their own repository
/// because they share one lifecycle with the write: [clearDraft] is only ever
/// correct immediately after [createBusinessPartner] succeeds, and splitting
/// them apart is how a saved draft outlives the depot it became.
abstract class BusinessPartnerRepository {
  /// Sends the registration with `Commit: true`, so a success means SAP wrote
  /// the partner and the returned depot number is real.
  ResultFuture<BusinessPartnerResult> createBusinessPartner(
    BusinessPartnerRequest request,
  );

  /// Runs the same payload with `Commit: false`.
  ///
  /// SAP validates and rolls back, so this answers "would this be accepted?"
  /// without creating anything. Worth a call before submit: the wizard can
  /// only check what the app knows, and half of what SAP rejects — a payment
  /// term not open for the sales org, a depot group the division does not
  /// carry — is invisible from the phone.
  ResultFuture<BusinessPartnerResult> validateBusinessPartner(
    BusinessPartnerRequest request,
  );

  /// The ERP catalogues backing the SAP-code dropdowns.
  ///
  /// **Never throws and never returns null.** Degrades fresh cache → stale
  /// cache → built-in lists, because an empty dropdown blocks the registration
  /// outright, which is the exact failure the offline-first design exists to
  /// prevent. Callers need no try/catch.
  ///
  /// [includeInactive] requests retired codes as well
  /// (`?includeInactive=true`). **The registration form must leave this
  /// false** — a retired code renders in a dropdown exactly like a live one,
  /// and a rep who picks one gets the push rejected with nothing on screen to
  /// explain it. It is for reading existing records, whose stored codes may
  /// since have been retired and still need a name on the detail screen.
  ///
  /// The two variants are cached separately, so asking for one does not change
  /// what the other screen sees.
  Future<SapReferenceOptions> loadReferenceOptions({
    bool includeInactive = false,
  });

  /// The rep's saved form, or null when they have none.
  ///
  /// Local only. Returns null rather than throwing on a shape change, so a
  /// draft written by an older build degrades to a blank form instead of a
  /// crash loop the rep cannot escape.
  Future<BpDepotDraft?> loadDraft();

  /// Persists the in-progress form. Fire-and-forget: a failed save must never
  /// interrupt typing.
  Future<void> saveDraft(BpDepotDraft draft);

  /// Drops the saved form. Called once the registration has been accepted, so
  /// the next "Add depot" opens blank.
  Future<void> clearDraft();
}
