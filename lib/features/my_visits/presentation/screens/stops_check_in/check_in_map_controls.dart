part of '../stops_check_in_screen.dart';

class _MapExpandButton extends StatelessWidget {
  const _MapExpandButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    // No BackdropFilter: a blur over a native map view is re-rendered every
    // frame the map moves, and on iOS that alone can make the map stutter.
    // A near-opaque card with a soft shadow reads the same.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: colors.card.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.open_in_full_rounded,
                  size: context.rr(13),
                  color: colors.textPrimary,
                ),
                SizedBox(width: context.rw(6)),
                Text(
                  'my_visits.route_info.expand_map'.tr,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: context.rsp(11.5),
                    fontWeight: FontWeight.w800,
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

class _FullScreenTransitMap extends StatelessWidget {
  const _FullScreenTransitMap({required this.stop});
  final RouteStop stop;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: colors.card,
        iconTheme: IconThemeData(color: colors.textPrimary),
        title: Text(
          'my_visits.route_info.route_map'.tr,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: context.rsp(16),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: BlocBuilder<LocationTrackingCubit, LocationTrackingState>(
        bloc: _resolveBloc<LocationTrackingCubit>(context),
        buildWhen: (previous, current) => previous.current != current.current,
        builder: (context, locationState) => TransitMap(
          target: stop,
          currentPosition: _mapPosition(stop, locationState),
        ),
      ),
    );
  }
}
