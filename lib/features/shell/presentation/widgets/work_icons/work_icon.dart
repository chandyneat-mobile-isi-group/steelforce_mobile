import 'package:flutter/material.dart';
import 'package:steelforce/features/shell/presentation/widgets/work_icons/depots_icon_painter.dart';
import 'package:steelforce/features/shell/presentation/widgets/work_icons/orders_icon_painter.dart';
import 'package:steelforce/features/shell/presentation/widgets/work_icons/visits_icon_painter.dart';

/// Hand-drawn, gently animated icons for the My Work grid.
///
/// ## Why these are drawn rather than rendered artwork
///
/// The reference sheet's illustrations came with their colour baked into a
/// tile, and separating figure from ground broke them wherever the two shared
/// a hue. Drawing them means the background is transparent by construction,
/// every colour is a brand token, they stay crisp at any size, and — the part
/// artwork cannot do — they can *move*.
///
/// ## The motion is deliberately slow
///
/// Each icon runs a ~5 second cycle in which the action occupies barely two
/// seconds and the rest is stillness. Three looping animations sit on the home
/// screen permanently; anything brisker turns a work screen into a fairground.
/// The action reads once, then rests, which is what "calm" means in a tool
/// somebody opens forty times a day.
///
/// Every icon honours `MediaQuery.disableAnimations` by holding its finished
/// frame — the drawing carries the meaning, only the movement is optional.
enum WorkIconKind { visits, depots, quotesOrders }

class WorkIcon extends StatefulWidget {
  const WorkIcon({
    super.key,
    required this.kind,
    required this.accent,
    required this.size,
  });

  final WorkIconKind kind;
  final Color accent;
  final double size;

  @override
  State<WorkIcon> createState() => _WorkIconState();
}

class _WorkIconState extends State<WorkIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop;

  @override
  void initState() {
    super.initState();
    _loop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5200),
    )..repeat();
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _loop,
          builder: (context, _) {
            // The frame every icon has finished on but none has begun to fade
            // from. It must sit after the *last* thing any of them draws —
            // the orders tick completes at 0.78 — and before the cycle fades
            // out at 0.90. Picking 0.62 (the moment the pin lands) left the
            // approval tick unstarted, so reduce-motion users saw a blank
            // green disc where the confirmation should be.
            final t = reduceMotion ? 0.84 : _loop.value;
            return CustomPaint(
              painter: switch (widget.kind) {
                WorkIconKind.visits =>
                  VisitsIconPainter(t: t, accent: widget.accent),
                WorkIconKind.depots =>
                  DepotsIconPainter(t: t, accent: widget.accent),
                WorkIconKind.quotesOrders =>
                  OrdersIconPainter(t: t, accent: widget.accent),
              },
            );
          },
        ),
      ),
    );
  }
}
