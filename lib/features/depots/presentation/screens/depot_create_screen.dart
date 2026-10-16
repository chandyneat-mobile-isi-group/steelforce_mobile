import 'package:flutter/material.dart';
import 'package:steelforce/features/depots/presentation/widgets/add_depot_bottom_sheet.dart';

/// Full-screen Create Business Partner flow.
///
/// The form itself is shared with the previous sheet implementation; keeping
/// its BLoC and validation in one place avoids diverging registration flows.
class DepotCreateScreen extends StatelessWidget {
  const DepotCreateScreen({super.key});

  static const routeName = 'depot-create';

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.sizeOf(context).width >= 600;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              scheme.primary,
              scheme.primary.withValues(alpha: 0.2), // Fades down
            ],
            stops: const [0.0, 0.5],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: AddDepotBottomSheet(isTablet: isTablet, isFullScreen: true),
        ),
      ),
    );
  }
}
