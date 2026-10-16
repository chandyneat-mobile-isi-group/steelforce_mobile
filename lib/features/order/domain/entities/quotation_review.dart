import 'package:equatable/equatable.dart';

/// Backend `status` codes, as the contract names them. Kept as strings, not an
/// enum: the contract warns that statuses past `Approved` are modelled but not
/// reachable yet, and a client that throws on an unknown name breaks the day
/// the next phase ships (`docs/feature/quotation-orders/api/mobile.md`).
abstract final class QuotationRemoteStatus {
  static const draft = 'Draft';
  static const returned = 'Returned';
  static const pendingApproval = 'PendingApproval';
  static const approved = 'Approved';
  static const rejected = 'Rejected';
  static const cancelled = 'Cancelled';

  /// The `Waiting` tab group — an administrator (or SAP, via the portal) still
  /// has the document. These are the only statuses worth polling: once a
  /// document leaves this set it has either come back to the rep or finished.
  static const waiting = <String>[
    pendingApproval,
    approved,
    'SubmittingToSap',
    'SapFailed',
    'SubmittingOrder',
    'OrderFailed',
  ];

  /// Still editable by the rep (the `Drafts` tab group).
  static bool isEditable(String status) =>
      status == draft || status == returned;
}

/// What the backend currently says about one submitted quotation.
class QuotationReview extends Equatable {
  const QuotationReview({
    required this.remoteId,
    required this.status,
    this.number,
    this.decisionReason,
  });

  final String remoteId;

  /// The backend's stable `status` code. `null` when the backend no longer
  /// knows the document (`404` — deleted, or not visible to this rep).
  final String? status;
  final String? number;

  /// Why an administrator returned or rejected it.
  final String? decisionReason;

  bool get isGone => status == null;

  @override
  List<Object?> get props => [remoteId, status, number, decisionReason];
}
