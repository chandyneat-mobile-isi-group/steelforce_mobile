import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';

/// The in-app explainer that earns the OS permission prompt
/// (`docs/feature/notification/README.md` §14).
///
/// ## Why a card and not just the OS prompt
///
/// iOS gives an app **one** prompt, ever. Fire it on first launch and a rep who
/// has no idea what the app does taps "Don't Allow", and there is no second
/// chance — only a support call talking them through system settings. So the
/// real prompt is bought with a sentence they can evaluate, shown at the moment
/// it means something: after they have seen their first route.
///
/// "Not now" is a first-class answer, not a dismissal to be worn down. It starts
/// a 14-day clock in `PushPermissionCubit`, and nothing here re-offers.
class PushPermissionCard extends StatelessWidget {
  const PushPermissionCard({
    super.key,
    required this.onEnable,
    required this.onDefer,
    this.busy = false,
  });

  final VoidCallback onEnable;
  final VoidCallback onDefer;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      margin: EdgeInsets.only(bottom: context.rh(12)),
      padding: EdgeInsets.all(context.rw(14)),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notifications_active_rounded,
                  size: context.rr(20), color: scheme.primary),
              SizedBox(width: context.rw(8)),
              Expanded(
                child: Text(
                  'notifications.permission.title'.tr,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: context.rsp(14),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: context.rh(6)),
          Text(
            'notifications.permission.body'.tr,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: context.rsp(12.5),
              height: 1.4,
            ),
          ),
          SizedBox(height: context.rh(12)),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: busy ? null : onEnable,
                  style: FilledButton.styleFrom(
                    // ≥48dp touch target (FEATURE_UI_STANDARD §14).
                    minimumSize: Size(0, context.rh(44)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: busy
                      ? SizedBox(
                          width: context.rr(16),
                          height: context.rr(16),
                          child:
                              const CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          'notifications.permission.enable'.tr,
                          style: TextStyle(
                            fontSize: context.rsp(13),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              SizedBox(width: context.rw(8)),
              // Not a bare text link. §14 treats declining as a legitimate
              // choice, and a "no" that is visibly harder to hit than "yes" is a
              // dark pattern — one that also costs the app its single iOS prompt
              // to a mis-tap.
              Expanded(
                child: OutlinedButton(
                  onPressed: busy ? null : onDefer,
                  style: OutlinedButton.styleFrom(
                    minimumSize: Size(0, context.rh(44)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'notifications.permission.later'.tr,
                    style: TextStyle(
                      fontSize: context.rsp(13),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The banner shown once the rep has declined (§14).
///
/// Deliberately quiet: no button that re-prompts, because on iOS a second
/// request does nothing at all and a button that silently does nothing is worse
/// than none. It says what is happening — the inbox still works — and points at
/// system settings, which is the only place the answer can actually change.
class PushPermissionDeclinedBanner extends StatelessWidget {
  const PushPermissionDeclinedBanner({super.key, this.onOpenSettings});

  /// Null on a platform where app settings cannot be opened; the row then reads
  /// as information rather than offering a tap that goes nowhere.
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return InkWell(
      onTap: onOpenSettings,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: EdgeInsets.only(bottom: context.rh(10)),
        padding: EdgeInsets.symmetric(
          horizontal: context.rw(12),
          vertical: context.rh(10),
        ),
        decoration: BoxDecoration(
          color: colors.surfaceSoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.notifications_off_rounded,
                size: context.rr(16), color: colors.iconMuted),
            SizedBox(width: context.rw(8)),
            Expanded(
              child: Text(
                'notifications.permission.declined_banner'.tr,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: context.rsp(11.5),
                  height: 1.35,
                ),
              ),
            ),
            if (onOpenSettings != null)
              Icon(Icons.chevron_right_rounded,
                  size: context.rr(18), color: colors.iconMuted),
          ],
        ),
      ),
    );
  }
}
