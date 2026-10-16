import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/notification/domain/entities/notification_category.dart';

/// How a notification category presents itself in the inbox.
@immutable
class NotificationCategoryStyle {
  const NotificationCategoryStyle({required this.icon, required this.color});

  final IconData icon;
  final Color color;
}

/// Icon, colour and label for each [NotificationCategory].
///
/// Extends the **domain** enum. An earlier version extended a two-value
/// `NotificationCategory` stub that lived next door in `presentation/widgets/`,
/// while every consumer imported the domain one — so the extension silently did
/// not apply, `label` and `style` came back undefined, and the import that was
/// supposed to supply them was reported unused. Two enums of the same name in
/// one feature is the whole bug; the stub is gone.
///
/// Presentation-only, and deliberately an extension rather than fields on the
/// enum: the domain entity must not import Flutter (ADR-003), and an icon is
/// not something the backend's category list has an opinion about.
extension NotificationCategoryPresentation on NotificationCategory {
  NotificationCategoryStyle style(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    return switch (this) {
      NotificationCategory.assignment => NotificationCategoryStyle(
          icon: Icons.assignment_turned_in_rounded, color: colors.info),
      NotificationCategory.quote => NotificationCategoryStyle(
          icon: Icons.request_quote_rounded, color: colors.accentPurple),
      NotificationCategory.order => NotificationCategoryStyle(
          icon: Icons.receipt_long_rounded, color: colors.warning),
      NotificationCategory.finance => NotificationCategoryStyle(
          icon: Icons.payments_rounded, color: colors.success),
      NotificationCategory.kpi => NotificationCategoryStyle(
          icon: Icons.insights_rounded, color: colors.info),
      NotificationCategory.approval => NotificationCategoryStyle(
          icon: Icons.verified_rounded, color: colors.success),
      NotificationCategory.account => NotificationCategoryStyle(
          icon: Icons.storefront_rounded, color: colors.brandNavy),
      NotificationCategory.system => NotificationCategoryStyle(
          icon: Icons.settings_suggest_rounded, color: colors.iconMuted),
      NotificationCategory.announce => NotificationCategoryStyle(
          icon: Icons.campaign_rounded, color: colors.accentPurple),
      // The only category drawn in an alarm colour. Everything else is
      // informational; a security notice is the one a rep must not scroll past.
      NotificationCategory.security => NotificationCategoryStyle(
          icon: Icons.shield_rounded, color: scheme.error),
      // A category this build has never heard of still renders — a
      // notification the rep cannot see is worse than a generic icon.
      NotificationCategory.unknown => NotificationCategoryStyle(
          icon: Icons.notifications_none_rounded, color: colors.iconMuted),
    };
  }

  /// Localised name. Keys already exist for every category under
  /// `notifications.category.*`; [NotificationCategory.unknown] maps to
  /// `other` rather than getting a key of its own, because "unknown" is a
  /// parsing outcome and not a word to show a rep.
  String get label => switch (this) {
        NotificationCategory.unknown => 'notifications.category.other'.tr,
        _ => 'notifications.category.$name'.tr,
      };
}

/// The two buckets the inbox filters by.
///
/// The backend's category list has ten entries and grows on its own release
/// cycle; ten chips is a filter row nobody reads. A rep only ever asks one of
/// two questions — *is this the company telling me something, or the app?* — so
/// the chips answer that, while each row keeps its own precise icon from
/// [NotificationCategoryPresentation.style].
///
/// Grouping lives here, in presentation, rather than in the query: the wire
/// contract still carries the real category, so nothing about the backend or
/// the sync layer changes, and restoring per-category chips later is a UI edit.
enum NotificationFilterGroup {
  /// Everything the business sends a rep: work, money, approvals, security.
  admin,

  /// The app talking about itself.
  system;

  /// [NotificationCategory.unknown] belongs to neither on purpose. It is a
  /// parsing outcome rather than a thing anyone chose to send, so it stays
  /// visible under "All" instead of being filed under a bucket that would
  /// imply someone meant it.
  bool contains(NotificationCategory category) => switch (this) {
        NotificationFilterGroup.system =>
          category == NotificationCategory.system,
        NotificationFilterGroup.admin =>
          category != NotificationCategory.system &&
              category != NotificationCategory.unknown,
      };

  String get label => switch (this) {
        NotificationFilterGroup.admin => 'notifications.category.admin'.tr,
        NotificationFilterGroup.system => 'notifications.category.system'.tr,
      };

  /// Borrows the colour of a representative category, so a chip and the rows it
  /// selects share an accent.
  Color color(BuildContext context) => switch (this) {
        NotificationFilterGroup.admin =>
          NotificationCategory.approval.style(context).color,
        NotificationFilterGroup.system =>
          NotificationCategory.system.style(context).color,
      };
}
