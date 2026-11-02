import 'package:equatable/equatable.dart';
import 'package:steelforce/features/depots/domain/entities/registration/depot_draft_attachment.dart';
import 'package:steelforce/features/depots/domain/entities/registration/mobile_depot_kind.dart';

/// The record as the server saved it — the subset of `MobileOutletView` the
/// app acts on after a create.
///
/// [id] is the canonical id for every later call (attachments, edits). It is
/// normally the id the app sent, but the server's answer is what is trusted.
class SavedDepotDraft extends Equatable {
  const SavedDepotDraft({
    required this.id,
    required this.version,
    required this.status,
    required this.nameEn,
    this.kind = MobileDepotKind.depot,
    this.isNew = true,
    this.canEdit = false,
    this.createdAt,
    this.attachments = const DepotDraftAttachments(),
  });

  final String id;

  /// Send back with an edit (`PUT`) — a draft changed since is a conflict.
  final int version;

  /// Raw approval status (`PendingApproval`, `Approved`, `Rejected`). Kept as
  /// text: a status this build does not know must display, not throw.
  final String status;
  final String nameEn;

  /// Which route owns the record's files: a depot draft or a non-depot.
  final MobileDepotKind kind;

  /// False when the server recognised a resend (200) rather than creating
  /// (201). Either way the draft exists exactly once.
  final bool isNew;
  final bool canEdit;
  final DateTime? createdAt;
  final DepotDraftAttachments attachments;

  SavedDepotDraft withIsNew(bool value) => SavedDepotDraft(
        id: id,
        version: version,
        status: status,
        nameEn: nameEn,
        kind: kind,
        isNew: value,
        canEdit: canEdit,
        createdAt: createdAt,
        attachments: attachments,
      );

  @override
  List<Object?> get props => [
        id,
        version,
        status,
        nameEn,
        kind,
        isNew,
        canEdit,
        createdAt,
        attachments
      ];
}
