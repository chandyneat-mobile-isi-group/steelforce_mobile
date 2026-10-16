import 'dart:convert';

import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/features/depots/data/models/business_partner_request_model.dart';
import 'package:steelforce/features/depots/data/models/queued_photo.dart';
import 'package:steelforce/features/depots/domain/entities/pending_depot_registration.dart';

/// A registration-queue row as the Sync Center shows it.
///
/// In-flight states read as their resting state: the rep sees "queued", not
/// the drain's private `sending` claim.
PendingDepotRegistration pendingRegistrationFromRow(
  DepotRegistrationQueueRow r,
) {
  final request = _readRequest(r.payload);
  final status = switch (DepotRegistrationQueueStatus.parse(r.status)) {
    DepotRegistrationQueueStatus.sending => DepotRegistrationQueueStatus.queued,
    DepotRegistrationQueueStatus.uploadingPhotos =>
      DepotRegistrationQueueStatus.photosPending,
    final s => s,
  };
  return PendingDepotRegistration(
    id: r.id,
    depotName: r.depotName,
    status: status,
    createdAt: r.createdAt,
    photosOutstanding: QueuedPhoto.decode(r.attachments).length,
    depotNumber: r.depotNumber,
    message: r.lastMessage,
    canReopen: r.draftJson != null,
    nextAttemptAt: r.nextAttemptAt,
    depotNameKh: request?.name3.trim().nullIfEmpty,
    phone: (request?.mobilePhone.trim().nullIfEmpty ??
        request?.telephone.trim().nullIfEmpty),
    address: request == null
        ? null
        : [request.houseNo.trim(), request.street.trim()]
            .where((p) => p.isNotEmpty)
            .join(' ')
            .nullIfEmpty,
    latitude: double.tryParse(request?.latitude ?? ''),
    longitude: double.tryParse(request?.longitude ?? ''),
    attempts: r.attempts,
    lastAttemptAt: r.lastAttemptAt,
  );
}

/// The stored request body, for display only. Tolerant: an unreadable body
/// shows the row without its details rather than failing the whole list.
BusinessPartnerRequestModel? _readRequest(String payload) {
  try {
    final json = jsonDecode(payload);
    if (json is! Map) return null;
    return BusinessPartnerRequestModel.fromJson(
      Map<String, dynamic>.from(json),
    );
  } catch (_) {
    return null;
  }
}

extension on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}
