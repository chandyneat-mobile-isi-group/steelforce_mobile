import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/depots/presentation/bloc/depot_sync_cubit.dart';
import 'package:steelforce/features/depots/presentation/bloc/depot_sync_state.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

/// What the depot pull is doing. "Syncing…" while it runs and a failure for
/// as long as it stands; a success ("211 updated") only briefly — it is news
/// when the screen opens, not something to keep reading.
class DepotSyncStatusBanner extends StatefulWidget {
  const DepotSyncStatusBanner({super.key});

  /// How long a success stays up before it fades away.
  static const successFor = Duration(seconds: 4);

  @override
  State<DepotSyncStatusBanner> createState() => _DepotSyncStatusBannerState();
}

class _DepotSyncStatusBannerState extends State<DepotSyncStatusBanner> {
  Timer? _timer;
  bool _showSuccess = false;

  @override
  void initState() {
    super.initState();
    // A pull that finished before this was built still gets its moment.
    if (context.read<DepotSyncCubit>().state is DepotSyncSucceeded) {
      _flashSuccess();
    }
  }

  void _flashSuccess() {
    _timer?.cancel();
    _showSuccess = true;
    _timer = Timer(DepotSyncStatusBanner.successFor, () {
      if (mounted) setState(() => _showSuccess = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    return BlocConsumer<DepotSyncCubit, DepotSyncState>(
      listenWhen: (previous, current) => current is DepotSyncSucceeded,
      listener: (_, __) => setState(_flashSuccess),
      builder: (context, state) {
        final banner = switch (state) {
          DepotSyncInProgress(:final isInitial) => _Banner(
              color: scheme.primary,
              icon: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: scheme.primary),
              ),
              text: isInitial ? 'depots.downloading'.tr : 'depots.syncing'.tr,
            ),
          DepotSyncFailed(:final message) => _Banner(
              color: scheme.error,
              icon: Icon(Icons.cloud_off_rounded,
                  size: context.rr(16), color: scheme.error),
              text: message,
            ),
          DepotSyncSucceeded(:final upserted, :final deleted)
              when _showSuccess && (upserted > 0 || deleted > 0) =>
            _Banner(
              color: colors.success,
              icon: Icon(Icons.check_circle_rounded,
                  size: context.rr(16), color: colors.success),
              text:
                  'depots.sync_updated'.tr.replaceAll('{count}', '$upserted') +
                      (deleted > 0
                          ? 'depots.sync_removed'
                              .tr
                              .replaceAll('{count}', '$deleted')
                          : ''),
            ),
          _ => const SizedBox.shrink(),
        };
        // Fades and folds away, so the list below slides up rather than
        // jumping.
        return AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: KeyedSubtree(
              key: ValueKey(banner is SizedBox ? 'none' : state.runtimeType),
              child: banner,
            ),
          ),
        );
      },
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.color, required this.icon, required this.text});
  final Color color;
  final Widget icon;
  final String text;

  /// On a solid card, not a tint: the screen sits on the blue wallpaper, and
  /// a see-through red under red text could not be read. The colour stays in
  /// the edge and the icon; the words are in the body text colour.
  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      margin: EdgeInsets.only(bottom: context.rh(10)),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(context.rr(12)),
        border: Border.all(color: color.withValues(alpha: 0.45)),
        boxShadow: colors.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: context.rw(4), color: color),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: context.rw(12), vertical: context.rh(10)),
                child: Row(
                  children: [
                    icon,
                    SizedBox(width: context.rw(10)),
                    Expanded(
                      child: Text(
                        text,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: context.rsp(12.5),
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
