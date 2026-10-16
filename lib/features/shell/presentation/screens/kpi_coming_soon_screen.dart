import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/shared/widgets/coming_soon_view.dart';

/// Shown in place of the KPI dashboard while it is switched off
/// (`FeatureFlags.kpi`). Opened from Home, so Back to Home just pops.
class KpiComingSoonScreen extends StatelessWidget {
  const KpiComingSoonScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(
        backgroundColor: colors.canvas,
        elevation: 0,
        centerTitle: false,
        title: Text('kpi.title'.tr,
            style: TextStyle(
                fontSize: context.rsp(18), fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: ComingSoonView(
          icon: Icons.insights_rounded,
          title: 'kpi.coming_soon.title'.tr,
          subtitle: 'kpi.coming_soon.subtitle'.tr,
          actionLabel: 'kpi.coming_soon.back_home'.tr,
          actionIcon: Icons.home_rounded,
          onAction: () => Navigator.of(context).maybePop(),
        ),
      ),
    );
  }
}
