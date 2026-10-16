import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gal/gal.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/localization/localized_builder.dart';
import 'package:steelforce/core/localization/localized_text_context.dart';
import 'package:steelforce/core/responsive/responsive_content_frame.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/depots/domain/entities/depot.dart';
import 'package:steelforce/features/depots/domain/entities/depot_activity_type.dart';
import 'package:steelforce/features/depots/domain/entities/depot_status.dart';
import 'package:steelforce/features/depots/presentation/bloc/depot_detail_cubit.dart';
import 'package:steelforce/features/depots/presentation/bloc/depot_detail_state.dart';
import 'package:steelforce/features/depots/presentation/widgets/add_hc_visit_dialog.dart';
import 'package:steelforce/features/my_visits/presentation/navigation/add_depot_to_today.dart';
import 'package:steelforce/features/depots/presentation/widgets/edit_depot_bottom_sheet.dart';
import 'package:steelforce/features/my_visits/presentation/screens/stop_information/order_history_screen.dart';
import 'package:steelforce/features/my_visits/presentation/screens/stop_information/promotions_screen.dart';
import 'package:steelforce/shared/widgets/app_bottom_sheet.dart';

part 'depot_detail/hero_header_card.dart';
part 'depot_detail/detail_tabs.dart';
part 'depot_detail/detail_tiles.dart';

const String _fallbackOutletId = 'BP-884920';
const String _fallbackOutletType = 'WHS / Retail';
const String _fallbackOutletTier = 'Diamond';
const String _fallbackOutletAction = 'Attack';
const String _fallbackOwnerName = 'Yim Vithou';
const String _fallbackPhone = '026 407 480';
const String _fallbackTelegram = '@phnom_penh_steel_outlet';
const String _fallbackAddress = 'St. 218, Mean Chey';
const double _fallbackLatitude = 11.55925;
const double _fallbackLongitude = 104.91601;

class DepotDetailScreen extends StatelessWidget {
  const DepotDetailScreen({super.key, required this.depotId});

  static const String routeName = 'depot-detail';
  final String depotId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<DepotDetailCubit>()..load(depotId),
      child: const _DepotDetailView(),
    );
  }
}

class _DepotDetailView extends StatefulWidget {
  const _DepotDetailView();

  @override
  State<_DepotDetailView> createState() => _DepotDetailViewState();
}

class _DepotDetailViewState extends State<_DepotDetailView> {
  void _openEditDepot(BuildContext context, Depot depot) {
    if (depot.status == DepotStatus.closed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Theme.of(context).colorScheme.error,
          content: const Text('This depot is closed and cannot be edited.'),
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
                  'Depot "${context.localized(updated.displayName)}" updated successfully.',
                ),
              ),
            );
          }
        },
      ),
    );
  }

  /// Confirms, then actually asks the server for the visit.
  ///
  /// The dialog alone used to be the whole feature: it logged a local activity
  /// and showed "added to HC visits", while nothing left the handset. The stop
  /// never appeared on My Visits and could never be checked in to.
  ///
  /// The note stays local. `POST /mobile/visits/ad-hoc` takes `sk` and
  /// `clientRequestId` and nothing else, so the note is recorded as a depot
  /// activity here — which is where it was already going — and is not sent.
  Future<void> _showAddHcVisit(
      BuildContext context, Depot depot, String sk) async {
    final note = await showAddHcVisitDialog(context, depot: depot);
    if (note == null || !context.mounted) return;

    final added = await addDepotToTodayVisits(
      context,
      depotId: depot.id,
      sk: sk,
      depotName: depot.shopName,
    );
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
          backgroundColor: colors.canvas,
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
                  tooltip: 'Add HC Visit',
                  // Disabled until SAP reports the depot back — the endpoint
                  // is keyed on its SAP code (`adHocVisitCode`).
                  onPressed: switch (loadedDepot.adHocVisitCode) {
                    final sk? => () =>
                        _showAddHcVisit(context, loadedDepot, sk),
                    null => null,
                  },
                ),
              if (loadedDepot != null &&
                  loadedDepot.status != DepotStatus.closed)
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Edit Depot',
                  onPressed: () => _openEditDepot(context, loadedDepot),
                ),
            ],
          ),
          body: SafeArea(
            child: BlocBuilder<DepotDetailCubit, DepotDetailState>(
              builder: (context, state) {
                return switch (state) {
                  DepotDetailLoaded() => ResponsiveContentFrame(
                      child: DefaultTabController(
                        length: 3,
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
                            SizedBox(height: context.rh(8)),
                            Container(
                              margin: EdgeInsets.symmetric(
                                  horizontal: context.pagePadding),
                              decoration: BoxDecoration(
                                color: colors.card,
                                borderRadius:
                                    BorderRadius.circular(context.rr(12)),
                                border: Border.all(color: colors.border),
                              ),
                              child: TabBar(
                                labelColor:
                                    Theme.of(context).colorScheme.primary,
                                unselectedLabelColor: colors.textSecondary,
                                indicatorColor:
                                    Theme.of(context).colorScheme.primary,
                                indicatorSize: TabBarIndicatorSize.tab,
                                indicatorWeight: 3,
                                labelStyle: TextStyle(
                                  fontSize: context.rsp(13),
                                  fontWeight: FontWeight.w800,
                                ),
                                unselectedLabelStyle: TextStyle(
                                  fontSize: context.rsp(13),
                                  fontWeight: FontWeight.w600,
                                ),
                                tabs: [
                                  Tab(text: 'depots.detail.tab_overview'.tr),
                                  Tab(text: 'depots.detail.tab_sales'.tr),
                                  Tab(text: 'depots.detail.tab_promos'.tr),
                                ],
                              ),
                            ),
                            Expanded(
                              child: TabBarView(
                                children: [
                                  _OverviewTab(
                                    depot: state.depot,
                                    onPhoneTap: _openPhoneOrTelegram,
                                    onLocationTap: _openGoogleMaps,
                                  ),
                                  _SalesTab(depot: state.depot),
                                  _PromosTab(depot: state.depot),
                                ],
                              ),
                            ),
                          ],
                        ),
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
          ),
        );
      },
    );
  }
}
