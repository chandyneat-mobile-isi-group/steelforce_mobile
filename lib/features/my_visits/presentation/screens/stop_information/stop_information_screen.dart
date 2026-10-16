import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gal/gal.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:steelforce/core/animations/page_transition.dart';
import 'package:steelforce/core/config/feature_flags.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/localization/localized_builder.dart';
import 'package:steelforce/core/localization/localized_text_context.dart';
import 'package:steelforce/core/responsive/responsive_content_frame.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_stop.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_status.dart';
import 'package:steelforce/features/my_visits/domain/services/geofence_service.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/active_route_bloc.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/location_tracking_cubit.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/visit_cubit.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/state/active_route_state.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/state/location_tracking_state.dart';
import 'package:steelforce/features/my_visits/presentation/navigation/end_visit.dart';
import 'package:steelforce/features/my_visits/presentation/screens/stop_information/order_history_screen.dart';
import 'package:steelforce/features/my_visits/presentation/screens/stop_information/promotions_screen.dart';
import 'package:steelforce/features/my_visits/presentation/screens/stops_check_in_screen.dart';
import 'package:steelforce/features/my_visits/presentation/widgets/visit_step_bar.dart';
import 'package:steelforce/core/utils/money.dart';
import 'package:steelforce/features/depots/domain/entities/depot_stop_information.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/stop_information_cubit.dart';
import 'package:intl/intl.dart';

part 'widgets/stop_hero_card.dart';
part 'widgets/stop_information_tabs.dart';
part 'widgets/stop_information_tiles.dart';
part 'widgets/stop_action_bar.dart';

class StopInformationScreen extends StatelessWidget {
  const StopInformationScreen({
    super.key,
    required this.stop,
    required this.index,
    required this.totalStops,
  });

  static const String routeName = 'stop_information';

  final RouteStop stop;
  final int index;
  final int totalStops;

  void _startVisit(BuildContext context) {
    HapticFeedback.mediumImpact();

    final ActiveRouteBloc activeRouteBloc =
        _resolveBloc<ActiveRouteBloc>(context);
    final VisitCubit visitCubit = _resolveBloc<VisitCubit>(context);
    final LocationTrackingCubit locationCubit =
        _resolveBloc<LocationTrackingCubit>(context);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LocalizedBuilder(
          builder: (_) => MultiBlocProvider(
            providers: [
              BlocProvider.value(value: activeRouteBloc),
              BlocProvider.value(value: visitCubit),
              BlocProvider.value(value: locationCubit),
            ],
            child: RouteCheckInScreen(stop: stop),
          ),
        ),
      ),
    );
  }

  void _completeVisit(BuildContext context) {
    HapticFeedback.mediumImpact();
    unawaited(endVisitAndSync(context));
  }

  static T _resolveBloc<T extends StateStreamableSource<Object?>>(
      BuildContext context) {
    try {
      return context.read<T>();
    } catch (_) {
      return sl<T>();
    }
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
  Widget build(BuildContext context) => LocalizedBuilder(builder: _build);

  Widget _build(BuildContext context) {
    final colors = context.appColors;

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
        bottom: VisitStepBar(current: VisitStepBar.forStatus(stop.status)),
        title: Text(
          'my_visits.stop_info.title'.tr,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: context.rsp(17),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: ResponsiveContentFrame(
          child: DefaultTabController(
            // Sales (credit and order history) is hidden while quotations
            // and orders are switched off.
            length: FeatureFlags.quotesAndOrders ? 3 : 2,
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.pagePadding,
                    vertical: context.rh(6),
                  ),
                  child: _HeroCard(
                    stop: stop,
                    onPhoneTap: _openPhoneOrTelegram,
                    onLocationTap: _openGoogleMaps,
                  ),
                ),
                SizedBox(height: context.rh(8)),
                Container(
                  margin: EdgeInsets.symmetric(horizontal: context.pagePadding),
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: BorderRadius.circular(context.rr(12)),
                    border: Border.all(color: colors.border),
                  ),
                  child: TabBar(
                    labelColor: Theme.of(context).colorScheme.primary,
                    unselectedLabelColor: colors.textSecondary,
                    indicatorColor: Theme.of(context).colorScheme.primary,
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
                      Tab(text: 'my_visits.stop_info.tab_overview'.tr),
                      if (FeatureFlags.quotesAndOrders)
                        Tab(text: 'my_visits.stop_info.tab_sales'.tr),
                      Tab(text: 'my_visits.stop_info.tab_promos'.tr),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _OverviewTab(
                        stop: stop,
                        onPhoneTap: _openPhoneOrTelegram,
                        onLocationTap: _openGoogleMaps,
                      ),
                      if (FeatureFlags.quotesAndOrders) _SalesTab(stop: stop),
                      _PromosTab(stop: stop),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _StopActionBar(
        stop: stop,
        bloc: _resolveBloc<ActiveRouteBloc>(context),
        onStart: () => _startVisit(context),
        onComplete: () => _completeVisit(context),
      ),
    );
  }
}
