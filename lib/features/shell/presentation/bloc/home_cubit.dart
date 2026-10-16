import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/features/shell/data/home_repository.dart';
import 'package:steelforce/features/shell/presentation/bloc/home_state.dart';

class HomeCubit extends Cubit<HomeState> {
  HomeCubit(this._repository) : super(const HomeInitial());

  final HomeRepository _repository;

  Future<void> load() async {
    emit(const HomeLoading());
    try {
      final summary = await _repository.fetchSummary();
      emit(HomeLoaded(summary));
    } catch (_) {
      emit(const HomeError("Couldn't load your dashboard"));
    }
  }

  Future<void> refresh() => load();
}

/// Lets any widget request a `MainShell` tab switch without needing a
/// `BuildContext` reference into `MainShell`'s private state (which is
/// StatefulWidget-private and can't be `context.read<>()`'d like a Bloc).
///
/// Register as a singleton in your DI container:
/// `sl.registerLazySingleton(() => ShellTabController());`
///
/// Usage from anywhere: `sl<ShellTabController>().goTo(ShellTab.orders)`.
class ShellTabController extends ValueNotifier<int> {
  ShellTabController() : super(0);

  void goTo(int index) => value = index;
}

/// Single source of truth for tab index <-> feature, so call sites never
/// hardcode magic numbers. Matches `MainShell`'s current tab order:
/// Home, Depots, My Visits, Orders.
///
/// `leads` was removed with the lead feature. Because these are positional
/// indices, dropping it moved Orders from 4 to 3 — which is exactly why call
/// sites go through this class instead of writing the number.
abstract class ShellTab {
  static const home = 0;
  static const depots = 1;
  static const myVisits = 2;
  static const orders = 3;
}
