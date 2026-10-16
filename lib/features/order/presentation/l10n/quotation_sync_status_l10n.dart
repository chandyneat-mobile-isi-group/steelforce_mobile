import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/features/order/domain/entities/quotation_sync_status.dart';

/// User-facing names for [QuotationSyncStatus], read from
/// `orders.sync_status.*` in `assets/lang/{en,km}.json`.
///
/// Lives in presentation, not on the enum. The enum previously carried a
/// `label` getter returning English literals, which put user-facing copy in the
/// domain layer (`docs/skills/feature-ui-standard.md` FS-NN-6, FS-LOC-1) and meant a
/// Khmer-reading rep saw "Sync failed" on every chip. The translations for
/// these nine states were already written in both language files and had no
/// caller — this connects them.
///
/// Same shape as `OffVisitReasonL10n`.
extension QuotationSyncStatusL10n on QuotationSyncStatus {
  String get localizedLabel => switch (this) {
        QuotationSyncStatus.draft => 'orders.sync_status.draft'.tr,
        QuotationSyncStatus.readyToSubmit =>
          'orders.sync_status.ready_to_submit'.tr,
        QuotationSyncStatus.pendingSync => 'orders.sync_status.pending_sync'.tr,
        QuotationSyncStatus.syncing => 'orders.sync_status.syncing'.tr,
        QuotationSyncStatus.submitted => 'orders.sync_status.submitted'.tr,
        QuotationSyncStatus.accepted => 'orders.sync_status.accepted'.tr,
        QuotationSyncStatus.rejected => 'orders.sync_status.rejected'.tr,
        QuotationSyncStatus.failed => 'orders.sync_status.failed'.tr,
        QuotationSyncStatus.conflict => 'orders.sync_status.conflict'.tr,
        QuotationSyncStatus.returned => 'orders.sync_status.returned'.tr,
      };
}
