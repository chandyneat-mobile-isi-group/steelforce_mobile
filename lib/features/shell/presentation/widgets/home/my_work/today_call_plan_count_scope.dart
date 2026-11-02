/// Provides the "N today" badge count to the My Visits tile on Home, and
/// refreshes it online-first whenever Home is shown. No visuals here.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/route_sync_cubit.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/today_call_plan_count_cubit.dart';
import 'package:steelforce/features/shell/presentation/navigation/shell_tab_controller.dart';

/// Owns the badge's [TodayCallPlanCountCubit] and keeps it online-first.
///
/// Each time Home is shown (and once on first build) it re-reads today's
/// plans — the list the Visits tab shows — so the two agree. Offline the
/// badge keeps its last count. The route sync still runs here for the older
/// visit screens, but the badge no longer waits on it.
class TodayCallPlanCountScope extends StatefulWidget {
  const TodayCallPlanCountScope({super.key, required this.child});

  final Widget child;

  @override
  State<TodayCallPlanCountScope> createState() =>
      _TodayCallPlanCountScopeState();
}

class _TodayCallPlanCountScopeState extends State<TodayCallPlanCountScope> {
  late final TodayCallPlanCountCubit _cubit;
  late final RouteSyncCubit _sync;
  final ShellTabController _tabs = sl<ShellTabController>();

  @override
  void initState() {
    super.initState();
    _cubit = sl<TodayCallPlanCountCubit>();
    _sync = sl<RouteSyncCubit>();
    _tabs.addListener(_onTabChanged);
    _pullThenCount();
  }

  void _onTabChanged() {
    if (_tabs.value == ShellTab.home) _pullThenCount();
  }

  Future<void> _pullThenCount() async {
    unawaited(_sync.syncIfNeeded());
    if (mounted) await _cubit.refresh();
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChanged);
    _sync.close();
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      BlocProvider.value(value: _cubit, child: widget.child);
}
