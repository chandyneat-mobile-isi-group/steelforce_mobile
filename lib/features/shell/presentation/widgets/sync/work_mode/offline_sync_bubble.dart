import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/features/shell/presentation/widgets/sync/pending_sync_sheet.dart';

/// The small **Syncing Data** popup pinned under the Offline pill, shown
/// whenever the app is offline — no tap needed to reveal it. It stands in for
/// the Pending Sync badge (hidden offline) and opens the Sync Center, whose
/// "Go online to sync" is one way back online; the pill itself is the other.
class OfflineSyncBubble extends StatelessWidget {
  const OfflineSyncBubble({super.key, this.onTap});

  /// Defaults to the Sync Center sheet; injectable for tests.
  final void Function(BuildContext context)? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = 'work_mode.syncing_data'.tr;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // The pointer up at the Offline pill: this belongs to it.
          CustomPaint(
            size: Size(context.rw(12), context.rh(6)),
            painter: _Caret(scheme.primary),
          ),
          Material(
            color: scheme.primary,
            shape: const StadiumBorder(),
            elevation: 3,
            shadowColor: Colors.black.withValues(alpha: 0.25),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: () => (onTap ?? showPendingSyncSheet)(context),
              // A comfortable target even though the bubble is small.
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 36),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.rw(10),
                    vertical: context.rh(5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sync_rounded,
                          size: context.rr(14), color: scheme.onPrimary),
                      SizedBox(width: context.rw(5)),
                      Text(
                        label,
                        style: TextStyle(
                          color: scheme.onPrimary,
                          fontSize: context.rsp(11.5),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Caret extends CustomPainter {
  const _Caret(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_Caret oldDelegate) => oldDelegate.color != color;
}
