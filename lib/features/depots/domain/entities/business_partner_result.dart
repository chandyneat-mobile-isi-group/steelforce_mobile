// =============================================================================
// business_partner_result.dart
//
// What comes back from `POST /api/v1/mobile/depots/business-partner`.
//
// The interesting part is [messages]. A SAP BAPI does not fail with an HTTP
// status — it returns 200 with a return table whose rows carry the verdict, so
// a call can be transport-successful and business-failed at the same time. The
// repository therefore inspects [hasError] rather than trusting the status code
// alone, and the rep sees SAP's own wording instead of "something went wrong".
// =============================================================================

import 'package:equatable/equatable.dart';

/// Severity of one SAP return row. `TYPE` in the BAPI structure.
enum SapMessageType {
  success, // S
  info, // I
  warning, // W
  error, // E
  abort, // A
  exit, // X
  unknown;

  static SapMessageType fromCode(String? code) =>
      switch (code?.trim().toUpperCase()) {
        'S' => SapMessageType.success,
        'I' => SapMessageType.info,
        'W' => SapMessageType.warning,
        'E' => SapMessageType.error,
        'A' => SapMessageType.abort,
        'X' => SapMessageType.exit,
        _ => SapMessageType.unknown,
      };

  /// `A` and `X` are terminated the unit of work; they are errors with a
  /// different name, and treating them as anything softer would report a
  /// registration as accepted when nothing was written.
  bool get isFailure =>
      this == SapMessageType.error ||
      this == SapMessageType.abort ||
      this == SapMessageType.exit;
}

/// One row of SAP's `BAPIRET2` return table.
class SapReturnMessage extends Equatable {
  const SapReturnMessage({
    required this.type,
    required this.message,
    this.id = '',
    this.number = '',
    this.field = '',
  });

  final SapMessageType type;
  final String message;

  /// Message class (`ID`) and number — together they identify the message in
  /// SE91, which is what an SAP consultant will ask for when a rep reports a
  /// rejection nobody can reproduce.
  final String id;
  final String number;

  /// The offending field, when SAP names one. Used to route the error back to
  /// the wizard step that owns it instead of showing a banner.
  final String field;

  bool get isError => type.isFailure;

  /// `ZBP/041`-style reference for logs and support tickets.
  String get code => id.isEmpty ? '' : '$id/$number';

  @override
  List<Object?> get props => [type, message, id, number, field];
}

/// The middleware's own lifecycle verdict, reported as `sapStatus`.
///
/// This is **not** the same question as "did SAP assign a number". A
/// registration parked for HQ approval is accepted and has no number yet, and
/// conflating the two is what made a successful submit report as a failure.
enum BpSubmissionStatus {
  /// Stored and awaiting HQ approval. No SAP number yet. **This is a success.**
  pendingHq,

  /// SAP created the partner; a depot number is present.
  created,

  /// Refused. The rep must change something.
  rejected,

  /// A status this build does not know.
  ///
  /// Treated as accepted rather than rejected: the server is the authority on
  /// its own lifecycle, it can add a state before this app ships again, and
  /// telling a rep their registration failed when it did not is the more
  /// expensive mistake — they re-register and HQ gets a duplicate.
  unknown;

  static BpSubmissionStatus fromCode(String? raw) {
    final code = raw?.trim().toUpperCase().replaceAll('-', '_');
    if (code == null || code.isEmpty) return BpSubmissionStatus.unknown;
    return switch (code) {
      'PENDING_HQ' ||
      'PENDING' ||
      'PENDINGHQ' ||
      'DRAFT' ||
      'SUBMITTED' =>
        BpSubmissionStatus.pendingHq,
      'CREATED' ||
      'REGISTERED' ||
      'SUCCESS' ||
      'ACTIVE' =>
        BpSubmissionStatus.created,
      'REJECTED' || 'FAILED' || 'ERROR' => BpSubmissionStatus.rejected,
      _ => BpSubmissionStatus.unknown,
    };
  }
}

class BusinessPartnerResult extends Equatable {
  const BusinessPartnerResult({
    this.depotNumber = '',
    this.partnerNumber = '',
    this.localId = '',
    this.status = BpSubmissionStatus.unknown,
    this.submittedToSap = false,
    this.messages = const [],
  });

  /// SAP depot number from the number range.
  ///
  /// Empty while the record is parked for HQ approval — SAP has not been asked
  /// for a number yet. An empty value is therefore **not** an error.
  final String depotNumber;

  /// BP number, when the middleware reports it separately from the depot
  /// number. Often the same value; kept apart because in an Extend-Depot
  /// scenario they are not.
  final String partnerNumber;

  /// The platform's own id for the record (`depotId`), which exists as soon
  /// as the registration is stored, with or without a SAP number.
  ///
  /// This — not [depotNumber] — is what the documents endpoint is addressed
  /// by, so it is what the evidence upload needs.
  final String localId;

  final BpSubmissionStatus status;
  final bool submittedToSap;
  final List<SapReturnMessage> messages;

  /// True when the server took the registration.
  ///
  /// The bar is deliberately *not* "has a depot number": a `PENDING_HQ`
  /// record is accepted, stored, and will be pushed to SAP after approval.
  /// Requiring a number here reported every pending registration as a failure
  /// and sent reps back to re-enter a shop that was already on file.
  bool get isAccepted =>
      !hasError &&
      status != BpSubmissionStatus.rejected &&
      (localId.isNotEmpty ||
          depotNumber.isNotEmpty ||
          partnerNumber.isNotEmpty);

  /// True when SAP actually assigned a number.
  ///
  /// Narrower than [isAccepted]. Use this only where a real SAP number is
  /// required; use [isAccepted] to decide whether the submit succeeded.
  bool get isCreated => depotNumber.isNotEmpty && !hasError;

  /// Accepted, but with no SAP number yet.
  bool get isPendingApproval => isAccepted && depotNumber.isEmpty;

  /// The id to file evidence against, preferring the platform id.
  String get documentId => localId.isNotEmpty ? localId : depotNumber;

  bool get hasError =>
      messages.any((m) => m.isError) || status == BpSubmissionStatus.rejected;

  List<SapReturnMessage> get errors =>
      messages.where((m) => m.isError).toList(growable: false);

  /// The first error, or the first message of any kind, worded for the rep.
  String? get primaryMessage {
    if (messages.isEmpty) return null;
    return (errors.isNotEmpty ? errors.first : messages.first).message;
  }

  /// Errors keyed by the SAP field they name, for per-field display.
  Map<String, String> get fieldErrors => {
        for (final e in errors)
          if (e.field.isNotEmpty) e.field: e.message,
      };

  @override
  List<Object?> get props => [
        depotNumber,
        partnerNumber,
        localId,
        status,
        submittedToSap,
        messages,
      ];
}
