import 'package:steelforce/features/order/domain/entities/admin_submit_result.dart';
import 'package:steelforce/features/order/domain/entities/quotation.dart';
import 'package:steelforce/features/order/domain/entities/quotation_api_entities.dart';
import 'package:steelforce/features/order/domain/entities/quotation_review.dart';

/// The outbound boundary between the device's saved quotations and the Admin
/// backend (`/api/v1/mobile/quotations`).
///
/// A rep's part ends at Admin Review: this pushes a local quotation up as a
/// backend document and submits it for approval, then reads back what the
/// administrator decided. It never reaches SAP — no mobile route can.
abstract interface class QuotationAdminGateway {
  /// Makes the backend document match [quotation] and submits it.
  ///
  /// [remoteId] is the backend document already linked to this quotation, if
  /// any; when null a new one is opened and [onRemoteCreated] is awaited with
  /// its id *before anything else is sent*, so a crash or timeout mid-way
  /// resumes on that document rather than opening a duplicate.
  Future<AdminSubmitResult> submit(
    Quotation quotation, {
    required String? remoteId,
    required Future<void> Function(String remoteId) onRemoteCreated,
  });

  /// The current review state of each of [remoteIds]. Throws on a transport
  /// failure — the caller keeps the last known state and tries later.
  Future<List<QuotationReview>> fetchReviews(List<String> remoteIds);

  /// The rep's editable documents on the backend (`Drafts` group: `Draft` and
  /// `Returned`) — including ones opened on another device or never saved
  /// locally. Throws on a transport failure.
  Future<List<QuotationSummary>> fetchEditableDrafts();
}
