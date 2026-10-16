import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/depots/presentation/bloc/depot_sync_cubit.dart';
import 'package:steelforce/features/depots/presentation/bloc/depot_sync_state.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

class DepotSyncStatusBanner extends StatelessWidget {
  const DepotSyncStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    return BlocBuilder<DepotSyncCubit, DepotSyncState>(
      builder: (context, state) {
        return switch (state) {
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
              when upserted > 0 || deleted > 0 =>
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
      },
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.color, required this.icon, required this.text});
  final Color color;
  final Widget icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          icon,
          SizedBox(width: context.rw(8)),
          Expanded(
              child: Text(text,
                  style: TextStyle(
                      color: color,
                      fontSize: context.rsp(12),
                      fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
