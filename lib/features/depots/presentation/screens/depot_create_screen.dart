import 'package:flutter/material.dart';
import 'package:steelforce/features/app_coach/domain/entities/coach_action.dart';
import 'package:steelforce/features/app_coach/presentation/services/app_coach.dart';
import 'package:steelforce/features/depots/data/models/depot_registration_type.dart';
import 'package:steelforce/features/depots/presentation/widgets/add_depot_bottom_sheet.dart';
import 'package:steelforce/shared/widgets/brand_wallpaper_background.dart';

/// Full-screen Create Business Partner flow.
///
/// The form itself is shared with the previous sheet implementation; keeping
/// its BLoC and validation in one place avoids diverging registration flows.
class DepotCreateScreen extends StatefulWidget {
  const DepotCreateScreen({super.key, this.registrationType});

  /// Pre-picks step 1's "Register as". Null leaves the form's own default.
  final DepotRegistrationType? registrationType;

  static const routeName = 'depot-create';

  @override
  State<DepotCreateScreen> createState() => _DepotCreateScreenState();
}

class _DepotCreateScreenState extends State<DepotCreateScreen> {
  @override
  void initState() {
    super.initState();
    // Once per opening; a no-op outside an App Coach lesson.
    AppCoach.notify(CoachAction.startCreateDepot);
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.sizeOf(context).width >= 600;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: BrandWallpaperBackground(
        style: BrandWallpaperStyle.vivid,
        child: SafeArea(
          bottom: false,
          child: AddDepotBottomSheet(
            isTablet: isTablet,
            isFullScreen: true,
            registrationType: widget.registrationType,
          ),
        ),
      ),
    );
  }
}
