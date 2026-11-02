import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';

/// The Sync Center's empty state: "Everything synced" with a cloud-done icon,
/// shown when the selected filter has nothing waiting.
class PendingSyncEmptyQueue extends StatelessWidget {
  const PendingSyncEmptyQueue({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_done_rounded,
                size: context.rr(40), color: colors.success),
            SizedBox(height: context.rh(10)),
            Text('sync.everything_synced'.tr,
                style: TextStyle(
                    color: scheme.onSurface, fontWeight: FontWeight.w700)),
            SizedBox(height: context.rh(4)),
            Text('sync.none_waiting'.tr,
                style: TextStyle(
                    color: colors.textSecondary, fontSize: context.rsp(12))),
          ],
        ),
      ),
    );
  }
}
