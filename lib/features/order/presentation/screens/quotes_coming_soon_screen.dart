import 'package:flutter/material.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/shell/presentation/bloc/home_cubit.dart';
import 'package:steelforce/shared/widgets/coming_soon_view.dart';

/// Shown in place of Quotations & Orders while the feature is switched off
/// (`FeatureFlags.quotesAndOrders`). Back returns to Home, as the real
/// Orders tab does.
class QuotesComingSoonScreen extends StatelessWidget {
  const QuotesComingSoonScreen({super.key});

  void _goHome(BuildContext context) {
    final navigator = Navigator.of(context);
    // Opened as its own route (a deep link): leave it. As the Orders tab:
    // switch the shell back to Home.
    if (navigator.canPop()) {
      navigator.pop();
    } else if (sl.isRegistered<ShellTabController>()) {
      sl<ShellTabController>().goTo(ShellTab.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: Navigator.of(context).canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goHome(context);
      },
      child: Scaffold(
        backgroundColor: context.appColors.canvas,
        body: SafeArea(
          child: ComingSoonView(
            icon: Icons.receipt_long_rounded,
            title: 'orders.coming_soon.title'.tr,
            subtitle: 'orders.coming_soon.subtitle'.tr,
            actionLabel: 'orders.coming_soon.back_home'.tr,
            actionIcon: Icons.home_rounded,
            onAction: () => _goHome(context),
          ),
        ),
      ),
    );
  }
}
