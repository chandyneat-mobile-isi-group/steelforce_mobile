part of '../stop_information_screen.dart';

class _StopActionBar extends StatelessWidget {
  const _StopActionBar({
    required this.stop,
    required this.bloc,
    required this.onStart,
    required this.onComplete,
  });

  final RouteStop stop;
  final ActiveRouteBloc bloc;
  final VoidCallback onStart;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ActiveRouteBloc, ActiveRouteState>(
      bloc: bloc,
      builder: (context, state) => _bar(context, _liveStatus(state)),
    );
  }

  VisitStatus _liveStatus(ActiveRouteState state) {
    if (state is! ActiveRouteReady) return stop.status;
    for (final s in state.route.stops) {
      if (s.id == stop.id) return s.status;
    }
    return stop.status;
  }

  Widget _bar(BuildContext context, VisitStatus status) {
    if (status == VisitStatus.checkedOut || status == VisitStatus.missed) {
      return _Chrome(child: _DoneMarker(status: status));
    }

    if (status != VisitStatus.checkedIn) {
      return _Chrome(child: _PrimaryAction(onPressed: onStart));
    }

    return _Chrome(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PrimaryAction(
            onPressed: onStart,
            icon: Icons.arrow_forward_rounded,
            labelKey: 'my_visits.stop_info.start_visit',
          ),
          SizedBox(height: context.rh(8)),
          SizedBox(
            width: double.infinity,
            height: context.rh(44),
            child: OutlinedButton.icon(
              onPressed: onComplete,
              icon: Icon(Icons.stop_circle_rounded, size: context.rr(18)),
              label: Text(
                'my_visits.inventory.completion.complete_visit'.tr,
                style: TextStyle(
                  fontSize: context.rsp(13.5),
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
                side: BorderSide(
                  color: Theme.of(context)
                      .colorScheme
                      .error
                      .withValues(alpha: 0.5),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(context.rr(12)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DoneMarker extends StatelessWidget {
  const _DoneMarker({required this.status});
  final VisitStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final done = status == VisitStatus.checkedOut;
    return SizedBox(
      height: context.rh(44),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.remove_circle_outline,
            size: context.rr(18),
            color: done ? colors.success : colors.textSecondary,
          ),
          SizedBox(width: context.rw(6)),
          Text(
            status.label,
            style: TextStyle(
              fontSize: context.rsp(13.5),
              fontWeight: FontWeight.w800,
              color: done ? colors.success : colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({
    required this.onPressed,
    this.icon = Icons.play_arrow_rounded,
    this.labelKey = 'my_visits.stop_info.start_visit',
  });

  final VoidCallback onPressed;
  final IconData icon;
  final String labelKey;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      height: context.rh(48),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: context.rr(20)),
        label: Text(
          labelKey.tr,
          style: TextStyle(
            fontSize: context.rsp(14.5),
            fontWeight: FontWeight.w800,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(context.rr(12)),
          ),
        ),
      ),
    );
  }
}

class _Chrome extends StatelessWidget {
  const _Chrome({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        border: Border(top: BorderSide(color: colors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, -4),
          )
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            context.pagePadding,
            context.rh(8),
            context.pagePadding,
            context.rh(8),
          ),
          child: child,
        ),
      ),
    );
  }
}
