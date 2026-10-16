import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/network/connectivity/connectivity_cubit.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/order/presentation/bloc/sync/pending_sync_cubit.dart';

/// Wraps the shell so that when connectivity is *restored* and quotations are
/// waiting, a short snackbar tells the rep they are on their way to Admin.
///
/// It used to *ask* ("Sync Now / Later") because sync was manual. Sync is now
/// automatic (`QuotationSyncCoordinator` reacts to the same reconnect), so this
/// only informs — the spec still forbids opening screens or navigating.
class ReconnectSyncListener extends StatelessWidget {
  const ReconnectSyncListener({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<ConnectivityCubit, ConnectivityStatus>(
      listenWhen: (prev, curr) =>
          prev == ConnectivityStatus.offline &&
          curr == ConnectivityStatus.online,
      listener: _onReconnected,
      child: child,
    );
  }

  void _onReconnected(BuildContext context, ConnectivityStatus _) {
    final pendingCubit = context.read<PendingSyncCubit>();
    final pending = pendingCubit.state.counts.pending;
    if (pending == 0) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          backgroundColor: context.appColors.slate,
          content: Text(
            'sync.connected_syncing'.trParams({'count': pending}),
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
  }
}
