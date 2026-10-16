import 'package:equatable/equatable.dart';

/// Where a queued depot registration is in its replay.
enum DepotRegistrationQueueStatus {
  /// Waiting to be sent. The sync engine sends it automatically.
  queued,

  /// Claimed by a drain and on the wire. A row left here by a process that
  /// died mid-send is moved to [needsReview], because SAP may have written it.
  sending,

  /// The server holds the registration; photographs are still uploading.
  /// Retried automatically — the depot exists, so this can never duplicate it.
  photosPending,

  /// Claimed by a drain that is uploading photographs. Shown to the rep as
  /// [photosPending]; a row stranded here by a dead process goes back there.
  uploadingPhotos,

  /// The outcome is unknown: the request went out and the answer never came.
  /// **Never retried automatically** — the endpoint takes no idempotency key,
  /// so a blind resend can create a second business partner in SAP. The rep
  /// checks the depot list, then retries or discards.
  needsReview,

  /// SAP refused it. Resending the same payload would be refused again, so the
  /// rep reopens it in the wizard, fixes it, and submits again.
  rejected;

  static DepotRegistrationQueueStatus parse(String raw) =>
      values.firstWhere((s) => s.name == raw, orElse: () => needsReview);

  /// Whether the rep has to act before this can move.
  bool get needsRep => this == needsReview || this == rejected;
}

/// True for the only server errors that prove a registration never reached
/// SAP: the gateway refusing it (502 Bad Gateway, 503 Unavailable).
///
/// Deliberately narrow. A 500 is the application server's own failure and can
/// be raised *after* SAP wrote the partner (a mirror write or response mapping
/// that failed afterwards); a 504 is the answer that never came. Either may
/// have landed, so neither may be resent without the rep checking first.
bool isSafeToResendServerError(int? statusCode) =>
    statusCode == 502 || statusCode == 503;

/// One registration in the outbox, as the Sync Center shows it.
class PendingDepotRegistration extends Equatable {
  const PendingDepotRegistration({
    required this.id,
    required this.depotName,
    required this.status,
    required this.createdAt,
    this.photosOutstanding = 0,
    this.depotNumber,
    this.message,
    this.canReopen = false,
    this.nextAttemptAt,
    this.depotNameKh,
    this.phone,
    this.address,
    this.latitude,
    this.longitude,
    this.attempts = 0,
    this.lastAttemptAt,
  });

  final String id;
  final String depotName;
  final DepotRegistrationQueueStatus status;
  final DateTime createdAt;
  final int photosOutstanding;

  /// The SAP number once registered; empty while HQ approval is pending.
  final String? depotNumber;

  /// The reason a row needs the rep. For a SAP refusal, SAP's own wording.
  final String? message;

  /// True when the original form was kept, so a refusal can be fixed in the
  /// wizard rather than typed again.
  final bool canReopen;

  /// When the next automatic attempt is allowed, for a row backing off.
  final DateTime? nextAttemptAt;

  // ── What the rep submitted, for the Sync Center's details view ──
  // Read back from the stored request; null when the request did not carry
  // it. Depot PII: shown on this device only, never logged.

  /// The Khmer shop name.
  final String? depotNameKh;

  /// The mobile number, or the landline when no mobile was given.
  final String? phone;

  /// House number and street, as typed.
  final String? address;
  final double? latitude;
  final double? longitude;

  /// Send attempts so far (photo rounds once the registration has landed).
  final int attempts;
  final DateTime? lastAttemptAt;

  @override
  List<Object?> get props => [
        id,
        depotName,
        status,
        createdAt,
        photosOutstanding,
        depotNumber,
        message,
        canReopen,
        nextAttemptAt,
        depotNameKh,
        phone,
        address,
        latitude,
        longitude,
        attempts,
        lastAttemptAt,
      ];
}
