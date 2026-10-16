import 'package:flutter/material.dart';
import 'package:steelforce/core/animations/app_animations.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';

/// The inventory step's Submit button: says how many photos are still
/// needed until enough exist, pulses once when it becomes available, and
/// shows saving progress and a save failure.
class InventorySubmitBar extends StatefulWidget {
  const InventorySubmitBar({
    super.key,
    required this.count,
    required this.minPhotos,
    required this.saving,
    required this.saveFailed,
    required this.onSubmit,
  });

  final int count;
  final int minPhotos;
  final bool saving;
  final bool saveFailed;
  final VoidCallback onSubmit;

  @override
  State<InventorySubmitBar> createState() => _InventorySubmitBarState();
}

class _InventorySubmitBarState extends State<InventorySubmitBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: AppDurations.page);

  late final Animation<double> _scale = TweenSequence([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.04), weight: 1),
    TweenSequenceItem(tween: Tween(begin: 1.04, end: 1.0), weight: 1),
  ]).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));

  bool get _ready => widget.count >= widget.minPhotos;

  @override
  void didUpdateWidget(InventorySubmitBar old) {
    super.didUpdateWidget(old);
    final wasReady = old.count >= old.minPhotos;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (_ready && !wasReady && !reduceMotion) _pulse.forward(from: 0);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final hint = _ready
        ? 'my_visits.survey.submit_hint'.trParams({'count': widget.count})
        : 'my_visits.survey.photos_needed'
            .trParams({'count': widget.minPhotos - widget.count});

    return Container(
      padding: EdgeInsets.fromLTRB(
          context.rw(16), context.rh(12), context.rw(16), context.rh(12)),
      decoration: BoxDecoration(
        color: colors.card,
        border: Border(top: BorderSide(color: colors.border)),
        boxShadow: colors.cardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSize(
            duration: AppDurations.medium,
            child: widget.saveFailed
                ? Padding(
                    padding: EdgeInsets.only(bottom: context.rh(8)),
                    child: Text('my_visits.inventory.save_failed'.tr,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: context.rsp(11.5),
                            fontWeight: FontWeight.w700,
                            color: scheme.error)),
                  )
                : const SizedBox(width: double.infinity),
          ),
          ScaleTransition(
            scale: _scale,
            child: ElevatedButton(
              onPressed: _ready && !widget.saving ? widget.onSubmit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
                disabledBackgroundColor: colors.border,
                disabledForegroundColor: colors.textDisabled,
                elevation: _ready ? 3 : 0,
                shadowColor: scheme.primary.withValues(alpha: 0.4),
                minimumSize: Size(double.infinity, context.rh(58)),
                padding: EdgeInsets.symmetric(vertical: context.rh(8)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(context.rr(14))),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      widget.saving
                          ? SizedBox.square(
                              dimension: context.rr(18),
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: scheme.onPrimary),
                            )
                          : Icon(Icons.send_rounded, size: context.rr(20)),
                      SizedBox(width: context.rw(10)),
                      Text('my_visits.survey.submit'.tr,
                          style: TextStyle(
                              fontSize: context.rsp(16),
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                  AnimatedSwitcher(
                    duration: AppDurations.medium,
                    child: Text(hint,
                        key: ValueKey(hint),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: context.rsp(11.5),
                            fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
