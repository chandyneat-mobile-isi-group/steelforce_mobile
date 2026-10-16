import 'package:equatable/equatable.dart';

/// Outcome of handing one quotation to the Admin backend for review.
///
/// Sealed so the sync processor must handle every branch. The split that
/// matters is *retryable* ([AdminTransportFailure]) against *needs the rep*
/// ([AdminRejected], [AdminNeedsReview]): retrying a business refusal
/// unchanged only burns data and attempts.
///
/// There is no SAP branch. The app never sends a quotation to SAP — the rep's
/// part ends at Admin Review, and an administrator puts it into SAP from the
/// portal (`docs/feature/quotation-orders/api/mobile.md`, rule 3).
sealed class AdminSubmitResult extends Equatable {
  const AdminSubmitResult();
  @override
  List<Object?> get props => [];
}

/// The backend holds the document and it is in review (or already past it).
final class AdminSubmitted extends AdminSubmitResult {
  const AdminSubmitted({
    required this.remoteId,
    required this.number,
    required this.remoteStatus,
  });

  final String remoteId;
  final String number;

  /// The backend's stable `status` code — `PendingApproval` on a fresh submit.
  final String remoteStatus;

  @override
  List<Object?> get props => [remoteId, number, remoteStatus];
}

/// The backend answered and refused on business rules (`422`, or a `404` for
/// a depot it does not know). Terminal until the rep changes something.
final class AdminRejected extends AdminSubmitResult {
  const AdminRejected({
    required this.errorCode,
    required this.message,
    this.remoteId,
  });

  /// The contract's `errorCode` — what the UI localizes from.
  final String errorCode;

  /// Developer detail for logs. Never shown to the rep as-is.
  final String message;
  final String? remoteId;

  @override
  List<Object?> get props => [errorCode, message, remoteId];
}

/// The backend needs the rep to look before it will take the document — today
/// only `409 Quotation.PriceChanged`, where the contract requires showing the
/// new prices before resubmitting rather than accepting them silently.
final class AdminNeedsReview extends AdminSubmitResult {
  const AdminNeedsReview({
    required this.errorCode,
    required this.message,
    required this.remoteId,
  });

  final String errorCode;
  final String message;
  final String remoteId;

  @override
  List<Object?> get props => [errorCode, message, remoteId];
}

/// No business answer — offline, timeout, `5xx`, `502 PriceUnavailable`.
/// Retryable under the backoff policy.
final class AdminTransportFailure extends AdminSubmitResult {
  const AdminTransportFailure({required this.message, this.errorCode});
  final String message;
  final String? errorCode;

  @override
  List<Object?> get props => [message, errorCode];
}
