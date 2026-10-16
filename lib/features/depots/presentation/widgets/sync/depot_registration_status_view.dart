import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/depots/domain/entities/pending_depot_registration.dart';

/// How a queued registration's status reads in the Sync Center — the chip
/// label, its colour, its icon and the sentence explaining it. Shared by the
/// card and the details sheet so the two never disagree.
abstract final class DepotRegistrationStatusView {
  static (String, Color) chip(
    BuildContext context,
    DepotRegistrationQueueStatus status,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    return switch (status) {
      DepotRegistrationQueueStatus.needsReview => (
          'sync_center.depot.status.needs_review'.tr,
          colors.warning,
        ),
      DepotRegistrationQueueStatus.rejected => (
          'sync_center.depot.status.rejected'.tr,
          scheme.error,
        ),
      DepotRegistrationQueueStatus.photosPending ||
      DepotRegistrationQueueStatus.uploadingPhotos =>
        (
          'sync_center.depot.status.photos'.tr,
          scheme.primary,
        ),
      DepotRegistrationQueueStatus.queued ||
      DepotRegistrationQueueStatus.sending =>
        (
          'sync_center.depot.status.queued'.tr,
          colors.textSecondary,
        ),
    };
  }

  static IconData icon(DepotRegistrationQueueStatus status) => switch (status) {
        DepotRegistrationQueueStatus.needsReview => Icons.help_outline_rounded,
        DepotRegistrationQueueStatus.rejected => Icons.error_outline_rounded,
        DepotRegistrationQueueStatus.photosPending ||
        DepotRegistrationQueueStatus.uploadingPhotos =>
          Icons.photo_library_outlined,
        _ => Icons.cloud_upload_outlined,
      };

  static String explanation(PendingDepotRegistration item) =>
      switch (item.status) {
        // Unknown outcome: never resent without the rep — see the outbox.
        DepotRegistrationQueueStatus.needsReview =>
          'sync_center.depot.needs_review_hint'.tr,
        // SAP's own words are the actionable part; shown verbatim.
        DepotRegistrationQueueStatus.rejected =>
          item.message?.isNotEmpty == true
              ? item.message!
              : 'sync_center.depot.rejected_hint'.tr,
        DepotRegistrationQueueStatus.photosPending ||
        DepotRegistrationQueueStatus.uploadingPhotos =>
          'sync_center.depot.photos_hint'.trParams({
            'count': item.photosOutstanding,
          }),
        _ => _waitingText(item),
      };

  /// Why a waiting row has not gone yet, and when it will try again — so a
  /// row stuck on a dead connection or a busy server says so instead of
  /// looking forgotten.
  static String _waitingText(PendingDepotRegistration item) {
    final reason = item.message;
    final base = reason != null && reason.startsWith('sync_center.')
        ? reason.tr
        : 'sync_center.depot.queued_hint'.tr;
    final next = item.nextAttemptAt;
    if (next == null || !next.isAfter(DateTime.now().toUtc())) return base;
    final time = DateFormat.Hm().format(next.toLocal());
    return '$base ${'sync_center.depot.next_try'.trParams({'time': time})}';
  }
}
