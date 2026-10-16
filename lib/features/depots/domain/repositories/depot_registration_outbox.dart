import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/depots/domain/entities/bp_depot_draft.dart';
import 'package:steelforce/features/depots/domain/entities/business_partner_request.dart';
import 'package:steelforce/features/depots/domain/entities/pending_depot_registration.dart';
import 'package:steelforce/features/depots/domain/repositories/depot_document_repository.dart';

/// Depot registrations submitted while SAP was out of reach.
///
/// The write succeeds locally first (ADR-002): [enqueue] stores the exact
/// request and its photographs in the encrypted database, and the sync engine
/// calls [drain] whenever the server is reachable.
///
/// ## The retry policy, and why it is asymmetric
///
/// `POST /mobile/depots/business-partner` takes no idempotency key and writes
/// to SAP synchronously. So a replay is only automatic when the previous
/// attempt provably never reached the server (no connection, connect or send
/// timeout, a gateway 5xx before SAP). When the request went out and the
/// answer was lost — a receive timeout, a 504, or the app dying mid-send — the
/// row stops at [DepotRegistrationQueueStatus.needsReview]: the rep checks
/// the depot list, then [retry]s or [discard]s. An automatic resend there is how
/// one shop becomes two business partners.
abstract interface class DepotRegistrationOutbox {
  /// Persists a registration for later replay and returns its id.
  ///
  /// [mayHaveLanded] stores it straight into review: the caller already saw
  /// the ambiguous failure. [draftSnapshot] is the wizard's form, kept so a SAP
  /// refusal can be reopened rather than retyped.
  ResultFuture<String> enqueue({
    required BusinessPartnerRequest request,
    required String depotName,
    required List<PendingDepotDocument> photos,
    bool mayHaveLanded = false,
    String? message,
    BpDepotDraft? draftSnapshot,
  });

  /// Sends the queued registrations one at a time, oldest first, with a short
  /// gap between them, uploading each one's photographs before the next goes.
  /// A registration that has to wait holds the ones behind it, so SAP receives
  /// them in the order the rep made them. Never throws; every transition is
  /// persisted as it happens.
  Future<void> drain();

  Stream<List<PendingDepotRegistration>> watchAll();

  /// Clears the backoff on every row still sent automatically, so the next
  /// drain tries them now. For the rep's explicit "Sync now".
  Future<void> expedite();

  /// Every row, including those waiting on the rep — sign-out must not wipe
  /// any of them.
  Future<int> countUnsent();

  /// Rows the drain still moves on its own — not those waiting on the rep.
  Future<int> countSendable();

  /// Returns a [DepotRegistrationQueueStatus.needsReview] row to the queue.
  /// The rep has confirmed the depot is not already on the list.
  ResultFuture<void> retry(String id);

  /// Drops the row and its photographs. For a registration that did land, or
  /// one the rep no longer wants.
  ResultFuture<void> discard(String id);

  /// Moves a refused row back into the Add Depot wizard as the saved draft,
  /// and removes it from the queue.
  ResultFuture<void> reopenAsDraft(String id);
}
