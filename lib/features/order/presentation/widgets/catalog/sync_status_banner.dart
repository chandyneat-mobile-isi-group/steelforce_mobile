import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/order/presentation/bloc/catalog/sync_cubit.dart';
import 'package:steelforce/features/order/presentation/bloc/catalog/sync_state.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

class SyncStatusBanner extends StatelessWidget {
  const SyncStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final appColors = context.appColors;

    return BlocBuilder<SyncCubit, SyncState>(
      builder: (context, state) {
        return switch (state) {
          SyncInProgress(:final isInitial) => _Banner(
              color: scheme.primary,
              icon: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: scheme.primary),
              ),
              text: isInitial
                  ? 'orders.catalog_sync.downloading'.tr
                  : 'common.syncing_latest'.tr,
            ),
          SyncFailed(:final message) => _Banner(
              color: scheme.error,
              icon: Icon(Icons.cloud_off_rounded,
                  size: context.rr(16), color: scheme.error),
              text: message,
            ),
          SyncSucceeded(:final upserted, :final deleted)
              when upserted > 0 || deleted > 0 =>
            _Banner(
              color: appColors.success,
              icon: Icon(Icons.check_circle_rounded,
                  size: context.rr(16), color: appColors.success),
              text:
                  'orders.catalog_sync.updated'.trParams({'count': upserted}) +
                      (deleted > 0
                          ? 'orders.catalog_sync.removed'
                              .trParams({'count': deleted})
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
        border: Border.all(color: color.withValues(alpha: 0.25)),
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
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
