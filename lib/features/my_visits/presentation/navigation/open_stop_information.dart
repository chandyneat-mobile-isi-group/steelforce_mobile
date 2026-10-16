import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/animations/page_transition.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_stop.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/active_route_bloc.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/location_tracking_cubit.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/stop_information_cubit.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/visit_cubit.dart';
import 'package:steelforce/features/my_visits/presentation/screens/stop_information/stop_information_screen.dart';

/// Opens StopInformationScreen with the blocs it needs, borrowing them from an
/// ancestor where one exists and creating them otherwise.
Future<void> openStopInformation(
  BuildContext context, {
  required RouteStop stop,
  required int index,
  required int totalStops,
}) {
  // Who owns each instance decides whether this route may close it, and the
  // two cases are genuinely different — see [_borrowOrCreate].
  final activeRoute = _borrowOrCreate<ActiveRouteBloc>(context);
  final visit = _borrowOrCreate<VisitCubit>(context);
  final location = _borrowOrCreate<LocationTrackingCubit>(context);

  return Navigator.of(context).push(
    AppPageRoute<void>.sharedAxisVertical(
      settings: const RouteSettings(name: StopInformationScreen.routeName),
      builder: (_) => MultiBlocProvider(
        providers: [
          activeRoute.provider,
          visit.provider,
          location.provider,
          // A fresh instance per stop, loading immediately: the screen opens on
          // the outlet the rep just tapped, and its details are wanted now.
          //
          // `create`, so this cubit is closed with the route — it belongs to
          // this screen, unlike the three above, which may be borrowed.
          BlocProvider<StopInformationCubit>(
            create: (_) => sl<StopInformationCubit>()..load(stop.depot.id),
          ),
        ],
        child: StopInformationScreen(
          stop: stop,
          index: index,
          totalStops: totalStops,
        ),
      ),
    ),
  );
}

/// A bloc plus whether this route is responsible for closing it.
///
/// ## Why this distinction has to be made
///
/// All three of these are registered with `registerFactory`, so `sl<T>()`
/// **builds a new instance every call** — it is not a shared singleton standing
/// in for the provided one.
///
/// This route used to wrap every instance in `BlocProvider.value`, which never
/// closes what it is given. That is right for a borrowed bloc (closing an
/// ancestor's bloc would break the screen underneath) and wrong for one this
/// route just created: opening a stop from the Stop Dashboard — which provides
/// none of the three — created an `ActiveRouteBloc`, a `VisitCubit` and a
/// `LocationTrackingCubit` and abandoned all three on the way back.
/// `LocationTrackingCubit` alone holds three stream subscriptions, cancelled
/// only in `close()`, so a rep working twenty stops accumulated twenty live
/// location subscriptions over a day.
class _BlocHandle<T extends StateStreamableSource<Object?>> {
  const _BlocHandle(this.instance, {required this.owned});

  final T instance;

  /// True when [instance] was created here, so this route must close it.
  final bool owned;

  /// `create` when owned (BlocProvider closes it), `value` when borrowed.
  BlocProvider<T> get provider => owned
      ? BlocProvider<T>(create: (_) => instance)
      : BlocProvider<T>.value(value: instance);
}

_BlocHandle<T> _borrowOrCreate<T extends StateStreamableSource<Object?>>(
    BuildContext context) {
  try {
    return _BlocHandle<T>(context.read<T>(), owned: false);
  } on Object {
    return _BlocHandle<T>(sl<T>(), owned: true);
  }
}
