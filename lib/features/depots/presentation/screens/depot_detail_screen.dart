import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gal/gal.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;
import 'package:url_launcher/url_launcher.dart';

import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/localization/localized_builder.dart';
import 'package:steelforce/core/localization/localized_text_context.dart';
import 'package:steelforce/core/responsive/responsive_content_frame.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/app_theme.dart';
import 'package:steelforce/core/theme/app_typography.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/app_coach/domain/entities/coach_action.dart';
import 'package:steelforce/features/app_coach/presentation/services/app_coach.dart';
import 'package:steelforce/features/app_coach/presentation/services/coach_keys.dart';
import 'package:steelforce/features/depots/domain/entities/depot.dart';
import 'package:steelforce/features/depots/domain/entities/depot_activity_type.dart';
import 'package:steelforce/features/depots/domain/entities/depot_list_kind.dart';
import 'package:steelforce/features/depots/domain/entities/depot_profile.dart';
import 'package:steelforce/features/depots/domain/entities/depot_sales_area.dart';
import 'package:steelforce/features/depots/domain/entities/depot_status.dart';
import 'package:steelforce/features/depots/presentation/bloc/depot_detail_cubit.dart';
import 'package:steelforce/features/depots/presentation/bloc/depot_detail_state.dart';
import 'package:steelforce/features/depots/presentation/navigation/open_depot_by_code.dart';
import 'package:steelforce/features/depots/presentation/widgets/add_hc_visit_dialog.dart';
import 'package:steelforce/features/my_visits/presentation/navigation/add_depot_to_today.dart';
import 'package:steelforce/features/depots/presentation/widgets/edit_depot_bottom_sheet.dart';
import 'package:steelforce/shared/widgets/app_bottom_sheet.dart';
import 'package:steelforce/shared/widgets/brand_wallpaper_background.dart';
import 'package:steelforce/core/assets/app_assets.dart';

part 'depot_detail/hero_header_card.dart';
part 'depot_detail/detail_sales_areas.dart';
part 'depot_detail/detail_tiles.dart';
part 'depot_detail/detail_sections.dart';
part 'depot_detail/detail_overview_tab.dart';
part 'depot_detail/detail_people_sections.dart';
part 'depot_detail/detail_section_nav.dart';
part 'depot_detail/detail_pill_row.dart';
part 'depot_detail/detail_general_section.dart';
part 'depot_detail/detail_document.dart';
part 'depot_detail/detail_document_capture.dart';
part 'depot_detail/detail_document_watermark.dart';

class DepotDetailScreen extends StatelessWidget {
  const DepotDetailScreen({
    super.key,
    required this.depotId,
    this.bottomAction,
  });

  static const String routeName = 'depot-detail';
  final String depotId;

  /// Pinned under the screen when the opener has an action for this depot —
  /// Start Visit, from a visit plan card. Null everywhere else.
  final Widget? bottomAction;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<DepotDetailCubit>()..load(depotId),
      child: _DepotDetailView(bottomAction: bottomAction),
    );
  }
}

class _DepotDetailView extends StatefulWidget {
  const _DepotDetailView({this.bottomAction});

  final Widget? bottomAction;

  @override
  State<_DepotDetailView> createState() => _DepotDetailViewState();
}

class _DepotDetailViewState extends State<_DepotDetailView> {
  @override
  void initState() {
    super.initState();
    // Once per opening; a no-op outside an App Coach lesson.
    AppCoach.notify(CoachAction.openDepotDetails);
  }

  /// Off: the Edit action is hidden from the details screen. The sheet and
  /// its save path are kept as they were — set true to offer it again.
  static const _editEnabled = false;

  void _openEditDepot(BuildContext context, Depot depot) {
    if (depot.status == DepotStatus.closed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Theme.of(context).colorScheme.error,
          content: Text('depots.detail.closed_cannot_edit'.tr),
        ),
      );
      return;
    }

    showAppBottomSheet(
      context: context,
      heightFactor: 0.9,
      builder: (_) => EditDepotBottomSheet(
        depot: depot,
        onSave: (updated) async {
          await context.read<DepotDetailCubit>().updateDepot(updated);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: Colors.green.shade700,
                content: Text(
                  'depots.detail.updated_success'.trParams(
                    {'name': context.localized(updated.displayName)},
                  ),
                ),
              ),
            );
          }
        },
      ),
    );
  }

  /// Confirms, then starts the ad hoc visit (`POST /mobile/plans/ad-hoc`).
  ///
  /// The note is not part of that request, so it stays local, recorded as a
  /// depot activity once the visit is on today.
  Future<void> _showAddHcVisit(BuildContext context, Depot depot) async {
    if (!await adHocVisitsAvailable(context, depot: depot) ||
        !context.mounted) {
      return;
    }
    final note = await showAddHcVisitDialog(context, depot: depot);
    if (note == null || !context.mounted) return;

    final added = await startAdHocVisitAt(context, depot);
    // Only on success: an activity reading "Scheduled as HC Visit" against a
    // visit the server refused is a note nobody can act on.
    if (!added || !context.mounted) return;

    await context.read<DepotDetailCubit>().logActivity(
          DepotActivityType.visit,
          'Scheduled as HC Visit${note.isNotEmpty ? ': $note' : ''}',
        );
  }

  Future<void> _openPhoneOrTelegram(String rawPhoneNumber) async {
    String cleanNumber = rawPhoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanNumber.startsWith('0')) {
      cleanNumber = '+855${cleanNumber.substring(1)}';
    } else if (!cleanNumber.startsWith('+')) {
      cleanNumber = '+$cleanNumber';
    }

    final Uri telegramTgUri = Uri.parse('tg://resolve?phone=$cleanNumber');
    final Uri telegramWebUri = Uri.parse('https://t.me/$cleanNumber');
    final Uri callUri = Uri.parse('tel:$cleanNumber');

    try {
      bool launched =
          await launchUrl(telegramTgUri, mode: LaunchMode.externalApplication);
      if (!launched) {
        launched = await launchUrl(telegramWebUri,
            mode: LaunchMode.externalApplication);
      }
      if (!launched) {
        await launchUrl(callUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      try {
        await launchUrl(callUri, mode: LaunchMode.externalApplication);
      } catch (err) {
        if (kDebugMode) debugPrint('Could not launch phone app: $err');
      }
    }
  }

  Future<void> _openGoogleMaps(double latitude, double longitude) async {
    final Uri googleMapsUri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
    );
    try {
      await launchUrl(googleMapsUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (kDebugMode) debugPrint('Could not launch Google Maps: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return LocalizedBuilder(
      builder: (context) {
        final colors = context.appColors;
        final detailState = context.watch<DepotDetailCubit>().state;
        final loadedDepot =
            detailState is DepotDetailLoaded ? detailState.depot : null;

        return Scaffold(
          backgroundColor: context.appColors.canvas,
          bottomNavigationBar: widget.bottomAction,
          appBar: AppBar(
            backgroundColor: colors.canvas,
            elevation: 0,
            scrolledUnderElevation: 0,
            toolbarHeight: context.rh(52),
            iconTheme: IconThemeData(
              color: colors.textPrimary,
              size: context.rr(22),
            ),
            title: Text(
              'depots.detail_title'.tr,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: context.rsp(17),
                fontWeight: FontWeight.w800,
              ),
            ),
            actions: [
              if (loadedDepot != null)
                IconButton(
                  icon: const Icon(Icons.add_location_alt_outlined),
                  tooltip: 'depots.hc_visit.title'.tr,
                  // Disabled while awaiting approval (`adHocOutlet`).
                  onPressed: loadedDepot.adHocOutlet == null
                      ? null
                      : () => _showAddHcVisit(context, loadedDepot),
                ),
              if (_editEnabled &&
                  loadedDepot != null &&
                  loadedDepot.status != DepotStatus.closed)
                CoachKeys.wrap(
                  CoachKeys.depotDetailEdit,
                  child: IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'depots.detail.edit_depot'.tr,
                    onPressed: () => _openEditDepot(context, loadedDepot),
                  ),
                ),
            ],
          ),
          body: BrandWallpaperBody(
              style: BrandWallpaperStyle.vivid,
              child: SafeArea(
                child: BlocBuilder<DepotDetailCubit, DepotDetailState>(
                  builder: (context, state) {
                    return switch (state) {
                      // No tabs: the four groups (General Information,
                      // Sales & Financial, Business Profile, Contact & Audit)
                      // are the whole page under the header.
                      DepotDetailLoaded() => ResponsiveContentFrame(
                          child: Column(
                            children: [
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: context.pagePadding,
                                  vertical: context.rh(6),
                                ),
                                child: _HeroHeaderCard(
                                  depot: state.depot,
                                  onPhoneTap: _openPhoneOrTelegram,
                                  onLocationTap: _openGoogleMaps,
                                ),
                              ),
                              Expanded(
                                child: _OverviewTab(
                                  depot: state.depot,
                                  onPhoneTap: _openPhoneOrTelegram,
                                  onLocationTap: _openGoogleMaps,
                                ),
                              ),
                            ],
                          ),
                        ),
                      DepotDetailError(:final message) => Center(
                          child: Text(message,
                              style: TextStyle(color: colors.textSecondary)),
                        ),
                      _ => Center(
                          child: CircularProgressIndicator(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                    };
                  },
                ),
              )),
        );
      },
    );
  }
}
