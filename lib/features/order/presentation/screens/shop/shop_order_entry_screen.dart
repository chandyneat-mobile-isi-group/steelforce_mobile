import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/localization/localized_builder.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/depots/domain/entities/depot.dart';
import 'package:steelforce/features/order/domain/entities/credit_summary.dart';
import 'package:steelforce/features/order/domain/entities/off_visit_reason.dart';
import 'package:steelforce/features/order/domain/usecases/capture_location_once.dart';
import 'package:steelforce/features/order/domain/usecases/catalog_params.dart';
import 'package:steelforce/features/order/domain/usecases/get_credit_summary.dart';
import 'package:steelforce/features/order/presentation/bloc/cart/cart_cubit.dart';
import 'package:steelforce/features/order/presentation/bloc/catalog/sync_cubit.dart';
import 'package:steelforce/features/order/presentation/screens/quotation/quotation_builder_screen.dart';
import 'package:steelforce/features/order/presentation/widgets/quotation/credit_summary_card.dart';
import 'package:steelforce/features/order/presentation/widgets/quotation/off_visit_reason_sheet.dart';
import 'package:steelforce/shared/widgets/back_to_home.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
// Import your BackToHomeButton path here
// import 'path_to/back_to_home_button.dart';

class ShopOrderEntryScreen extends StatefulWidget {
  const ShopOrderEntryScreen({
    super.key,
    required this.depot,
    this.skipOffVisitCheck = false,
    this.seedSearchTerm,
  });

  static const routeName = 'order-shop-entry';

  final Depot depot;
  final bool skipOffVisitCheck;
  final String? seedSearchTerm;

  @override
  State<ShopOrderEntryScreen> createState() => _ShopOrderEntryScreenState();
}

class _ShopOrderEntryScreenState extends State<ShopOrderEntryScreen> {
  late Future<CreditSummary?> _summaryFuture;
  OffVisitReason? _reason;
  ({double lat, double lng})? _gps;
  bool _capturingGps = true;

  @override
  void initState() {
    super.initState();
    _summaryFuture =
        sl<GetCreditSummary>()(GetCreditSummaryParams(widget.depot.id)).then(
      (result) => result.when(success: (s) => s, failure: (_) => null),
    );
    _captureGps();
  }

  Future<void> _captureGps() async {
    final position = await sl<CaptureLocationOnce>()();
    if (!mounted) return;
    setState(() {
      _gps = position;
      _capturingGps = false;
    });
  }

  Future<void> _startQuotation() async {
    if (!widget.skipOffVisitCheck && _reason == null) {
      final picked = await showOffVisitReasonSheet(context: context);
      if (picked == null || !mounted) return;
      setState(() => _reason = picked);
    }
    if (!mounted) return;

    Navigator.of(context).push(MaterialPageRoute(
      settings: const RouteSettings(name: QuotationBuilderScreen.routeName),
      builder: (_) => MultiBlocProvider(
        providers: [
          // No catalog pre-load: the builder opens on the guided product
          // configurator, which fetches categories only.
          //
          // TODO(order): `seedSearchTerm` (the out-of-stock item handed over
          // from Route Stock Count) no longer pre-seeds a catalog search — the
          // guided flow has no catalog-wide search to seed. Re-express it as a
          // pre-selected category once the SAP schema exposes a product →
          // category resolve endpoint.
          BlocProvider(create: (_) => sl<CartCubit>()..load()),
          BlocProvider(create: (_) => sl<SyncCubit>()),
        ],
        child: LocalizedBuilder(
          builder: (_) => QuotationBuilderScreen(
            depot: widget.depot,
            offVisitReason: widget.skipOffVisitCheck ? null : _reason,
            gpsLat: _gps?.lat,
            gpsLng: _gps?.lng,
          ),
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) => LocalizedBuilder(builder: _build);

  Widget _build(BuildContext context) {
    final depot = widget.depot;
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(
        backgroundColor: colors.canvas,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        // Left Side: Chevron Icon + Title
        title: Row(
          children: [
            IconButton(
              icon: Icon(
                Icons.chevron_left_rounded,
                color: colors.textPrimary,
                size: context.rsp(28),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: Text(
                depot.shopName,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: context.rsp(17),
                  fontWeight: FontWeight.w800,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        // Right Side: Back to home button
        actions: [
          Padding(
            padding: EdgeInsets.only(right: context.rw(16)),
            child: const BackToHomeButton(label: 'Back to home'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        children: [
          Text(depot.address,
              style: TextStyle(
                  color: colors.textPrimary, fontSize: context.rsp(13))),
          Text('${depot.district}, ${depot.province}',
              style: TextStyle(
                  color: colors.textSecondary, fontSize: context.rsp(12))),
          SizedBox(height: context.rh(14)),
          FutureBuilder<CreditSummary?>(
            future: _summaryFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return Center(
                    child: Padding(
                        padding: EdgeInsets.all(context.rr(20)),
                        child: CircularProgressIndicator(
                            color: colors.accentPurple)));
              }
              final summary = snapshot.data;
              if (summary == null) {
                return const SizedBox.shrink();
              }
              return CreditSummaryCard(
                  creditLimit: depot.creditLimit, summary: summary);
            },
          ),
          if (!widget.skipOffVisitCheck) ...[
            SizedBox(height: context.rh(14)),
            _OffVisitBanner(
                reason: _reason,
                onPick: () async {
                  final picked = await showOffVisitReasonSheet(
                      context: context, initial: _reason);
                  if (picked != null) setState(() => _reason = picked);
                }),
          ],
          SizedBox(height: context.rh(14)),
          Row(
            children: [
              Icon(Icons.gps_fixed_rounded,
                  size: context.rr(15), color: colors.textSecondary),
              SizedBox(width: context.rw(6)),
              Text(
                _capturingGps
                    ? 'orders.shop.capture_gps'.tr
                    : _gps == null
                        ? 'orders.shop.capture_gps'.tr
                        : '${_gps!.lat.toStringAsFixed(5)}, ${_gps!.lng.toStringAsFixed(5)}',
                style: TextStyle(
                    color: colors.textSecondary, fontSize: context.rsp(12)),
              ),
            ],
          ),
          SizedBox(height: context.rh(24)),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _startQuotation,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.accentPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text('orders.shop.start_quotation'.tr,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
          SizedBox(height: context.rh(10)),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('orders.shop.pick_another_shop'.tr),
            ),
          ),
        ],
      ),
    );
  }
}

class _OffVisitBanner extends StatelessWidget {
  const _OffVisitBanner({required this.reason, required this.onPick});
  final OffVisitReason? reason;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      padding: EdgeInsets.all(context.rr(12)),
      decoration: BoxDecoration(
        color: colors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded,
              color: colors.warning, size: context.rr(18)),
          SizedBox(width: context.rw(10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('orders.shop.off_visit_warning'.tr,
                    style: TextStyle(
                        color: colors.warning,
                        fontSize: context.rsp(12.5),
                        fontWeight: FontWeight.w600,
                        height: 1.35)),
                if (reason != null) ...[
                  SizedBox(height: context.rh(6)),
                  Text(reason!.localizedLabel,
                      style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: context.rsp(12),
                          fontWeight: FontWeight.w700)),
                ],
              ],
            ),
          ),
          TextButton(
              onPressed: onPick,
              child: Text(reason == null
                  ? 'orders.shop.start_quotation'.tr
                  : 'orders.quotation.edit_quotation'.tr)),
        ],
      ),
    );
  }
}
