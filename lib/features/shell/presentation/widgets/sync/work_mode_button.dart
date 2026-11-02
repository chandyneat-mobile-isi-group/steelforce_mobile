import 'package:flutter/material.dart';
import 'package:steelforce/core/theme/app_colors.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:steelforce/core/animations/app_animations.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/network/work_mode/work_mode_service.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/shell/presentation/bloc/work_mode_cubit.dart';
import 'package:steelforce/features/shell/presentation/widgets/sync/work_mode/work_mode_pill_content.dart';
import 'package:steelforce/features/shell/presentation/widgets/sync/work_mode_confirm_dialog.dart';

/// The shell's Online / Offline control, beside the Pending Sync badge.
///
/// Shows the mode in force; a tap offers the other one. Framed like
/// [PendingSyncBadge] so the two read as one group.
class WorkModeButton extends StatelessWidget {
  const WorkModeButton({super.key, this.cubit});

  /// Defaults to the app-wide instance; injectable for tests.
  final WorkModeCubit? cubit;

  @override
  Widget build(BuildContext context) {
    final bloc = cubit ?? sl<WorkModeCubit>();
    return BlocBuilder<WorkModeCubit, WorkModeState>(
      bloc: bloc,
      builder: (context, state) {
        final scheme = Theme.of(context).colorScheme;
        final colors = context.appColors;
        final offline = state.isOffline;
        final accent = offline ? colors.slate : colors.success;
        final label = offline ? 'work_mode.offline'.tr : 'work_mode.online'.tr;
        final target = offline ? WorkMode.online : WorkMode.offline;
        // Implicit animations only: each runs for one switch and owns its
        // own controller, so nothing ticks at rest. Instant under the
        // phone's Reduce Motion setting.
        final motion = MediaQuery.maybeOf(context)?.disableAnimations ?? false
            ? Duration.zero
            : AppDurations.medium;

        return Semantics(
          button: true,
          label: 'work_mode.semantics'.trParams({'mode': label}),
          excludeSemantics: true,
          child: InkWell(
            onTap: state.switching
                ? null
                : () => requestWorkModeSwitch(context, target, cubit: bloc),
            borderRadius: BorderRadius.circular(context.rr(24)),
            // 48dp tall tap target around a compact pill.
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Center(
                widthFactor: 1,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.rw(10),
                    vertical: context.rh(6),
                  ),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(context.rr(24)),
                    border: Border.all(color: AppColors.steelRim, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8.r,
                        offset: Offset(0, context.rh(3)),
                      ),
                    ],
                  ),
                  // The pill eases to its new width (Online and Offline
                  // differ) instead of jumping. Left out under Reduce
                  // Motion: an AnimatedSize with a zero duration throws
                  // during layout.
                  child: _sized(
                    motion,
                    WorkModePillContent(
                      offline: offline,
                      switching: state.switching,
                      label: label,
                      accent: accent,
                      labelColor: offline ? colors.textPrimary : accent,
                      motion: motion,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static Widget _sized(Duration motion, Widget child) => motion == Duration.zero
      ? child
      : AnimatedSize(
          duration: motion,
          curve: AppCurves.emphasized,
          child: child,
        );
}

/// Navigators with a switch request in progress, so a second tap while the
/// dialog is opening cannot stack a second dialog. Keyed by navigator rather
/// than a global flag: if a navigator is torn down mid-dialog, the one that
/// replaces it starts clear instead of leaving the control dead.
final Expando<bool> _requestOpen = Expando<bool>('workModeRequest');

/// Confirms, applies and reports a switch to [target]. Shared by the shell
/// control and the sync sheet's "Go online to sync", so both explain the mode
/// the same way.
Future<void> requestWorkModeSwitch(
  BuildContext context,
  WorkMode target, {
  WorkModeCubit? cubit,
  WorkModePrompt prompt = WorkModePrompt.manual,
}) async {
  final navigator = Navigator.of(context);
  if (_requestOpen[navigator] == true) return;
  _requestOpen[navigator] = true;
  try {
    await _requestSwitch(context, target, cubit ?? sl<WorkModeCubit>(), prompt);
  } finally {
    _requestOpen[navigator] = null;
  }
}

Future<void> _requestSwitch(
  BuildContext context,
  WorkMode target,
  WorkModeCubit bloc,
  WorkModePrompt prompt,
) async {
  if (bloc.state.switching || bloc.state.mode == target) return;

  final unsent = await bloc.unsentCount();
  if (!context.mounted) return;

  final toOffline = target == WorkMode.offline;
  final confirmed = await WorkModeConfirmDialog.show(
    context,
    toOffline: toOffline,
    unsent: unsent,
    prompt: prompt,
  );
  if (!confirmed) return;

  final result = await bloc.switchTo(target);
  if (!context.mounted) return;
  final message = switch (result) {
    WorkModeSwitchResult.offline => 'work_mode.now_offline'.tr,
    WorkModeSwitchResult.online => 'work_mode.now_online'.tr,
    WorkModeSwitchResult.onlineNoConnection =>
      'work_mode.now_online_no_connection'.tr,
    WorkModeSwitchResult.failed => 'work_mode.switch_failed'.tr,
    WorkModeSwitchResult.ignored => null,
  };
  if (message == null) return;
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
