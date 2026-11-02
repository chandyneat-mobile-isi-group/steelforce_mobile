import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/shell/presentation/widgets/sync/work_mode/work_mode_dialog_actions.dart';
import 'package:steelforce/features/shell/presentation/widgets/sync/work_mode/work_mode_dialog_header.dart';
import 'package:steelforce/features/shell/presentation/widgets/sync/work_mode/work_mode_unsent_note.dart';
import 'package:steelforce/shared/widgets/brand_wallpaper_background.dart';

/// Why the switch is being offered: the rep's own tap, or the app noticing
/// the connection dropped or came back.
enum WorkModePrompt { manual, connectionLost, connectionBack }

/// Confirms a switch between Online and Offline Mode.
///
/// Built like `LogoutConfirmDialog`: a [BrandWallpaperBackground] header with
/// the mode's icon, then the explanation and full-width actions. The header
/// uses the vivid brand blue (the wallpaper's own theme tokens), since this
/// is a routine choice, not a destructive one.
///
/// Pieces live in `work_mode/`: [WorkModeDialogHeader], [WorkModeUnsentNote]
/// and [WorkModeDialogActions].
class WorkModeConfirmDialog extends StatelessWidget {
  const WorkModeConfirmDialog({
    super.key,
    required this.toOffline,
    required this.unsent,
    this.prompt = WorkModePrompt.manual,
  });

  /// The mode being switched to.
  final bool toOffline;

  /// Changes the title and text to say what the app noticed.
  final WorkModePrompt prompt;

  /// Work saved on this device and not yet sent; reassures the rep it is safe.
  final int unsent;

  /// Resolves to `true` when confirmed, `false` when cancelled or dismissed.
  static Future<bool> show(
    BuildContext context, {
    required bool toOffline,
    required int unsent,
    WorkModePrompt prompt = WorkModePrompt.manual,
  }) async {
    final result = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (_, __, ___) => WorkModeConfirmDialog(
          toOffline: toOffline, unsent: unsent, prompt: prompt),
      transitionBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeIn,
        );
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    final boxScale =
        context.responsive(compact: 1.0, medium: 1.20, expanded: 1.30);
    final typeScale =
        context.responsive(compact: 1.0, medium: 1.25, expanded: 1.35);
    final maxMeasure = context.responsive(
      compact: 380.0,
      medium: 420.0,
      expanded: 440.0,
    );

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: 20 * boxScale,
          vertical: 24 * boxScale,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxMeasure),
          child: Material(
            color: c.card,
            elevation: 12,
            shadowColor: Colors.black.withValues(alpha: 0.30),
            borderRadius: BorderRadius.circular(28 * boxScale),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                WorkModeDialogHeader(toOffline: toOffline, boxScale: boxScale),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    24 * boxScale,
                    20 * boxScale,
                    24 * boxScale,
                    20 * boxScale,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        switch (prompt) {
                          WorkModePrompt.connectionLost =>
                            'work_mode.lost_title'.tr,
                          WorkModePrompt.connectionBack =>
                            'work_mode.back_title'.tr,
                          _ when toOffline => 'work_mode.to_offline_title'.tr,
                          _ => 'work_mode.to_online_title'.tr,
                        },
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 21 * typeScale,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                      SizedBox(height: 8 * boxScale),
                      Text(
                        switch (prompt) {
                          WorkModePrompt.connectionLost =>
                            'work_mode.lost_body'.tr,
                          WorkModePrompt.connectionBack =>
                            'work_mode.back_body'.tr,
                          _ when toOffline => 'work_mode.to_offline_body'.tr,
                          _ => 'work_mode.to_online_body'.tr,
                        },
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 14 * typeScale,
                          height: 1.45,
                        ),
                      ),
                      if (unsent > 0) ...[
                        SizedBox(height: 16 * boxScale),
                        WorkModeUnsentNote(
                          unsent: unsent,
                          boxScale: boxScale,
                          typeScale: typeScale,
                        ),
                      ],
                      SizedBox(height: 22 * boxScale),
                      WorkModeDialogActions(
                        toOffline: toOffline,
                        boxScale: boxScale,
                        typeScale: typeScale,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
