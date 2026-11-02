import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/pending_plan_visits_cubit.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/depots/presentation/bloc/depot_registration_queue_cubit.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/pending_visit_sync_cubit.dart';
import 'package:steelforce/features/order/presentation/bloc/sync/pending_sync_cubit.dart';
import 'package:steelforce/features/shell/presentation/widgets/sync/pending_sync/pending_sync_center_view.dart';
import 'package:steelforce/shared/widgets/app_bottom_sheet.dart';

/// The "Sync Center" — a bottom sheet listing work on its way to the server:
/// depot registrations saved offline, visit check-ins and check-outs, and
/// quotations on their way to the Admin backend with what the backend or an
/// administrator said. The rep's actions:
/// **Sync Now**, per-item **Retry** / **Fix** / **Discard**, and **Review
/// prices** for a price-change conflict. Depot and visit cards also carry
/// **Sync** (the same send-everything drain) and open their details on tap.
/// Syncing itself is automatic; this is visibility and control, not the
/// trigger.
///
/// Uses the shell's cubits when [context] is under them. A screen pushed on
/// its own route (Profile) is not, so the sheet then makes its own, which
/// close with it.
///
/// The sheet's pieces live in `pending_sync/`: the body
/// ([PendingSyncCenterView]), header, filter tiles, quotation tiles and the
/// empty state.
Future<void> showPendingSyncSheet(BuildContext context) {
  final cubit = _readOrNull<PendingSyncCubit>(context);
  final depots = _readOrNull<DepotRegistrationQueueCubit>(context);
  final visits = _readOrNull<PendingVisitSyncCubit>(context);
  final plans = _readOrNull<PendingPlanVisitsCubit>(context);
  return showModalBottomSheet<void>(
    constraints: const BoxConstraints(maxWidth: AppBottomSheet.maxWidth),
    context: context,
    isScrollControlled: true,
    backgroundColor: context.appColors.surfaceSoft,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => MultiBlocProvider(
      providers: [
        cubit != null
            ? BlocProvider.value(value: cubit)
            : BlocProvider(create: (_) => sl<PendingSyncCubit>()),
        depots != null
            ? BlocProvider.value(value: depots)
            : BlocProvider(create: (_) => sl<DepotRegistrationQueueCubit>()),
        visits != null
            ? BlocProvider.value(value: visits..load())
            : BlocProvider(create: (_) => sl<PendingVisitSyncCubit>()..load()),
        plans != null
            ? BlocProvider.value(value: plans)
            : BlocProvider(create: (_) => sl<PendingPlanVisitsCubit>()),
      ],
      child: const PendingSyncCenterView(),
    ),
  );
}

T? _readOrNull<T extends StateStreamableSource<Object?>>(BuildContext context) {
  // `context.read`, not `BlocProvider.of`: the latter rethrows a missing
  // provider as a plain FlutterError, which this cannot tell apart.
  try {
    return context.read<T>();
  } on ProviderNotFoundException {
    return null;
  }
}
