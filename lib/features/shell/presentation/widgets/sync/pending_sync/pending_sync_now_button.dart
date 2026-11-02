import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/network/work_mode/work_mode_service.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/features/depots/presentation/bloc/depot_registration_queue_cubit.dart';
import 'package:steelforce/features/order/presentation/bloc/sync/pending_sync_cubit.dart';
import 'package:steelforce/features/shell/presentation/bloc/work_mode_cubit.dart';
import 'package:steelforce/features/shell/presentation/widgets/sync/work_mode_button.dart';

/// The Sync Center's **Sync Now** button — or, in Offline Mode, the
/// "Go online to sync" button that offers the way out.
class PendingSyncNowButton extends StatelessWidget {
  const PendingSyncNowButton({super.key, required this.isSyncing});
  final bool isSyncing;

  @override
  Widget build(BuildContext context) {
    // Offline mode sends nothing, a tap here included: offer the way out
    // instead of a button that would silently do nothing.
    return BlocBuilder<WorkModeCubit, WorkModeState>(
      bloc: sl<WorkModeCubit>(),
      builder: (context, mode) => mode.isOffline
          ? FilledButton.icon(
              onPressed: mode.switching
                  ? null
                  : () => requestWorkModeSwitch(context, WorkMode.online),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              icon: Icon(Icons.wifi_rounded, size: context.rr(16)),
              label: Text('work_mode.go_online_to_sync'.tr),
            )
          : _button(context),
    );
  }

  Widget _button(BuildContext context) {
    return FilledButton.icon(
      onPressed: isSyncing
          ? null
          : () {
              context.read<PendingSyncCubit>().syncNow();
              context.read<DepotRegistrationQueueCubit>().syncNow();
            },
      style: FilledButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.primary,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),
      icon: isSyncing
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
          : Icon(Icons.sync_rounded, size: context.rr(16)),
      label: Text(isSyncing ? 'sync.syncing'.tr : 'sync.sync_now'.tr),
    );
  }
}
