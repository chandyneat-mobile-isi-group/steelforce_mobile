import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/animations/app_animations.dart';
import 'package:steelforce/core/animations/press_scale.dart';
import 'package:steelforce/core/animations/staggered_list.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/localization/localized_builder.dart';
import 'package:steelforce/core/permissions/presentation/app_permissions_cubit.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';

/// Shows the permission primer and resolves to true once the rep has answered.
///
/// ## Motion
///
/// `docs/skills/motion-framer.md` is a **React/Framer Motion** skill — its API
/// does not exist in Flutter — so what is carried across is its *method*, mapped
/// onto the motion tokens this repo already mandates
/// (`docs/skills/feature-ui-standard.md` §14: `AppDurations`/`AppCurves` only,
/// reduce-motion honoured):
///
/// | Framer Motion | Here |
/// |---|---|
/// | `initial` / `animate` | the `transitionBuilder` below |
/// | `staggerChildren` | [StaggeredList.wrap] over the permission rows |
/// | `whileTap={{ scale }}` | [PressScale] |
/// | `AnimatePresence` | `AnimatedSwitcher` on each row's status |
/// | `layout` | `AnimatedSize` as a row's subtitle changes length |
/// | spring / `easeOutBack` | [AppCurves.emphasized] |
/// | `useReducedMotion` | `MediaQuery.disableAnimations` |
///
/// Its performance rule is followed too: only transform and opacity are
/// animated, never width or height directly.
///
/// ## Barrier behaviour
///
/// Not dismissible by tapping outside, and the back button is captured. Not to
/// trap the rep — "Not now" is right there and is a first-class answer — but
/// because a dismissal that is neither an accept nor a decline leaves the app
/// unable to tell whether to re-offer, and this dialog is capped at once every
/// 14 days. An ambiguous close would spend that window on nothing.
Future<bool?> showPermissionPrimerDialog({
  required BuildContext context,
  required AppPermissionsCubit cubit,
}) {
  final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'permissions.primer.title'.tr,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: reduceMotion ? Duration.zero : AppDurations.entrance,
    pageBuilder: (_, __, ___) => BlocProvider.value(
      value: cubit,
      child: const _PermissionPrimerDialog(),
    ),
    transitionBuilder: (context, animation, _, child) {
      if (reduceMotion) return child;

      final eased = CurvedAnimation(
        parent: animation,
        curve: AppCurves.emphasized,
        reverseCurve: AppCurves.standard,
      );
      // Transform + opacity only. Animating the card's size would relayout the
      // whole subtree every frame — the pitfall the motion skill's performance
      // section names.
      return FadeTransition(
        opacity: eased,
        child: Transform.scale(
          scale: 0.92 + 0.08 * eased.value,
          child: Transform.translate(
            offset: Offset(0, 24 * (1 - eased.value)),
            child: child,
          ),
        ),
      );
    },
  );
}

class _PermissionPrimerDialog extends StatelessWidget {
  const _PermissionPrimerDialog();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return LocalizedBuilder(
      builder: (context) =>
          BlocConsumer<AppPermissionsCubit, AppPermissionsState>(
        listenWhen: (previous, current) => !previous.settled && current.settled,
        // Closed from the listener rather than from the button handlers, so
        // every path out — accept, skip, or a sequence that ended early because
        // nothing was left to ask — closes exactly once and in one place.
        listener: (context, state) => Navigator.of(context).pop(true),
        builder: (context, state) {
          return Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: context.pagePadding),
              child: ConstrainedBox(
                // Caps the measure on a tablet. A permission dialog stretched
                // across 1032pt reads as a web page, not a decision.
                constraints: const BoxConstraints(maxWidth: 420),
                child: Material(
                  color: colors.card,
                  borderRadius: BorderRadius.circular(24),
                  clipBehavior: Clip.antiAlias,
                  child: SingleChildScrollView(
                    // A short viewport — landscape, or a small phone at the
                    // tablet type scale — must scroll rather than overflow.
                    child: Padding(
                      padding: EdgeInsets.all(context.rw(20)),
                      child: _Body(state: state),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state});

  final AppPermissionsState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    // `staggerChildren`. The rows arrive one after another so the eye is led
    // down the list instead of meeting four blocks at once.
    final children = StaggeredList.wrap(
      [
        const _Hero(),
        SizedBox(height: context.rh(16)),
        _Title(needsSettings: state.needsSettings),
        SizedBox(height: context.rh(20)),
        for (final permission in state.visiblePermissions) ...[
          _PermissionRow(
            permission: permission,
            outcome: state.outcomeFor(permission),
          ),
          SizedBox(height: context.rh(10)),
        ],
        SizedBox(height: context.rh(8)),
        _Actions(state: state),
      ],
      enabled: !reduceMotion,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ...children,
        SizedBox(height: context.rh(4)),
        // The reassurance that makes a decline safe to choose. §1: the inbox is
        // the notification, so a rep who says no loses acceleration, not work.
        Text(
          'permissions.primer.footnote'.tr,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.textHint,
            fontSize: context.rsp(11),
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

/// The icon cluster. Purely decorative, and hidden from screen readers so a
/// non-visual reader is not read three icon names before the title.
class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;

    return ExcludeSemantics(
      child: Center(
        child: Container(
          width: context.rr(72),
          height: context.rr(72),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                scheme.primary.withValues(alpha: 0.16),
                colors.accentPurple.withValues(alpha: 0.10),
              ],
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(Icons.notifications_active_rounded,
                  size: context.rr(30), color: scheme.primary),
              Positioned(
                right: context.rr(12),
                bottom: context.rr(12),
                child: Container(
                  padding: EdgeInsets.all(context.rr(4)),
                  decoration: BoxDecoration(
                    color: colors.card,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.location_on_rounded,
                      size: context.rr(14), color: colors.accentPurple),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title({required this.needsSettings});

  final bool needsSettings;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Column(
      children: [
        Text(
          'permissions.primer.title'.tr,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: context.rsp(19),
            fontWeight: FontWeight.w900,
            height: 1.25,
          ),
        ),
        SizedBox(height: context.rh(6)),
        // `layout`: the copy changes length when a permission turns out to need
        // the settings app, and the card resizes smoothly rather than snapping.
        AnimatedSize(
          duration: AppDurations.medium,
          curve: AppCurves.standard,
          child: Text(
            needsSettings
                ? 'permissions.primer.subtitle_blocked'.tr
                : 'permissions.primer.subtitle'.tr,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: context.rsp(13),
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

/// One permission: why it is wanted, and where it currently stands.
class _PermissionRow extends StatelessWidget {
  const _PermissionRow({required this.permission, required this.outcome});

  final AppPermission permission;
  final PermissionOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final granted = outcome == PermissionOutcome.granted;
    final blocked = outcome == PermissionOutcome.blocked;

    final (icon, titleKey, reasonKey) = switch (permission) {
      AppPermission.notifications => (
          Icons.notifications_active_rounded,
          'permissions.notifications.title',
          'permissions.notifications.reason',
        ),
      AppPermission.location => (
          Icons.my_location_rounded,
          'permissions.location.title',
          'permissions.location.reason',
        ),
    };

    return Semantics(
      // The pip is a colour and a glyph; a screen reader needs the state said.
      label: '${titleKey.tr}. ${_statusLabel(outcome)}',
      child: AnimatedContainer(
        duration: AppDurations.medium,
        curve: AppCurves.standard,
        padding: EdgeInsets.all(context.rw(12)),
        decoration: BoxDecoration(
          color: granted
              ? colors.success.withValues(alpha: 0.06)
              : blocked
                  ? Theme.of(context).colorScheme.error.withValues(alpha: 0.05)
                  : colors.surfaceSoft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: granted
                ? colors.success.withValues(alpha: 0.45)
                : blocked
                    ? Theme.of(context)
                        .colorScheme
                        .error
                        .withValues(alpha: 0.35)
                    : colors.border,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: context.rr(20),
              color: granted ? colors.success : colors.iconMuted,
            ),
            SizedBox(width: context.rw(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titleKey.tr,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: context.rsp(13.5),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: context.rh(2)),
                  AnimatedSize(
                    duration: AppDurations.medium,
                    curve: AppCurves.standard,
                    alignment: Alignment.topLeft,
                    child: Text(
                      // Once blocked, the reason is no longer the useful thing
                      // to say — how to fix it is.
                      blocked
                          ? 'permissions.${permission.name}.blocked'.tr
                          : reasonKey.tr,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: context.rsp(11.5),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: context.rw(8)),
            _StatusPip(outcome: outcome),
          ],
        ),
      ),
    );
  }

  String _statusLabel(PermissionOutcome outcome) => switch (outcome) {
        PermissionOutcome.granted => 'permissions.status.granted'.tr,
        PermissionOutcome.asking => 'permissions.status.asking'.tr,
        PermissionOutcome.declined => 'permissions.status.declined'.tr,
        PermissionOutcome.blocked => 'permissions.status.blocked'.tr,
        PermissionOutcome.pending ||
        PermissionOutcome.unavailable =>
          'permissions.status.pending'.tr,
      };
}

/// The live status glyph.
///
/// `AnimatePresence`'s job: the outgoing glyph fades and shrinks out while the
/// incoming one fades in, so pending → asking → granted reads as one object
/// changing rather than three that replace each other.
class _StatusPip extends StatelessWidget {
  const _StatusPip({required this.outcome});

  final PermissionOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final size = context.rr(22);

    final child = switch (outcome) {
      PermissionOutcome.granted => Icon(Icons.check_circle_rounded,
          key: const ValueKey('granted'), size: size, color: colors.success),
      PermissionOutcome.asking => SizedBox(
          key: const ValueKey('asking'),
          width: size * 0.7,
          height: size * 0.7,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: scheme.primary,
          ),
        ),
      PermissionOutcome.blocked => Icon(Icons.settings_rounded,
          key: const ValueKey('blocked'), size: size, color: scheme.error),
      PermissionOutcome.declined => Icon(Icons.remove_circle_outline_rounded,
          key: const ValueKey('declined'), size: size, color: colors.textHint),
      PermissionOutcome.pending || PermissionOutcome.unavailable => Icon(
          Icons.circle_outlined,
          key: const ValueKey('pending'),
          size: size,
          color: colors.border,
        ),
    };

    return SizedBox(
      width: size,
      height: size,
      child: AnimatedSwitcher(
        duration: AppDurations.medium,
        switchInCurve: AppCurves.emphasized,
        switchOutCurve: AppCurves.standard,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: animation, child: child),
        ),
        child: child,
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.state});

  final AppPermissionsState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AppPermissionsCubit>();
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final busy = state.isRequesting;

    // Nothing left the OS will prompt for, so the primary action becomes the
    // only thing that can still change the answer. Offering "Enable" here would
    // be a button that fires a request the OS refuses to show.
    final settingsOnly = state.needsSettings && !state.hasAnythingToAsk;

    return Column(
      children: [
        PressScale(
          enabled: !busy,
          onTap: busy
              ? null
              : () => settingsOnly ? cubit.openSettings() : cubit.requestAll(),
          child: Container(
            // ≥48dp target (feature-ui-standard §14).
            height: context.rh(50),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color:
                  busy ? scheme.primary.withValues(alpha: 0.5) : scheme.primary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: AnimatedSwitcher(
              duration: AppDurations.fast,
              child: busy
                  ? SizedBox(
                      key: const ValueKey('busy'),
                      width: context.rr(18),
                      height: context.rr(18),
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      key: ValueKey(settingsOnly),
                      settingsOnly
                          ? 'permissions.primer.open_settings'.tr
                          : 'permissions.primer.enable'.tr,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: context.rsp(14.5),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
        ),
        SizedBox(height: context.rh(8)),
        // Not a faint text link. §14 treats declining as a legitimate answer,
        // and a "no" that is visibly harder to hit than "yes" is a dark pattern
        // — one that also costs the app its single iOS prompt to a mis-tap.
        PressScale(
          enabled: !busy,
          onTap: busy ? null : () => cubit.skip(),
          child: Container(
            height: context.rh(48),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.border),
            ),
            child: Text(
              'permissions.primer.later'.tr,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: context.rsp(14),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
