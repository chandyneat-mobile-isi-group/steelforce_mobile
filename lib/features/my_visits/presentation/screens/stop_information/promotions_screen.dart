import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:steelforce/core/animations/app_animations.dart';
import 'package:steelforce/core/animations/fade_slide_transition.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/localization/localized_builder.dart';
import 'package:steelforce/core/responsive/responsive_content_frame.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/my_visits/presentation/screens/stop_information/promotions_mock_data.dart';
import 'package:steelforce/features/order/domain/usecases/quotation_api_usecases.dart';
import 'package:steelforce/shared/widgets/promotions/promo_card.dart';
import 'package:steelforce/shared/widgets/promotions/promo_filter_bar.dart';
import 'package:steelforce/shared/widgets/promotions/promo_tone.dart';
import 'package:steelforce/shared/widgets/promotions/promo_view.dart';

/// Every promotion a rep can quote at one outlet.
///
/// Opened from the visit's stop-information screen, mid-visit, usually
/// one-handed. The design target is that a rep can answer "what can I offer
/// this depot today" without reading a single card end to end: the rate leads,
/// the countdown says whether it still counts, and anything expired sinks to
/// the bottom instead of competing for the top of the list.
class PromotionsScreen extends StatefulWidget {
  const PromotionsScreen({
    super.key,
    this.depotId,
    this.outletName,
    this.promotions,
    this.now,
  });

  static const String routeName = 'promotions';

  /// The depot/outlet ID to fetch promotions for.
  final String? depotId;

  final String? outletName;

  /// Injectable so a test can pin the data set. Falls back to the tagged mock
  /// list until the promotions data layer exists.
  final List<PromoView>? promotions;

  /// Injectable clock — the countdown and the expired/active split both depend
  /// on it, and a test that used the real clock would start failing on a date
  /// nobody chose.
  final DateTime? now;

  @override
  State<PromotionsScreen> createState() => _PromotionsScreenState();
}

class _PromotionsScreenState extends State<PromotionsScreen> {
  static const _offeredKinds = [
    PromoKind.onInvoice,
    PromoKind.paymentTerm,
    PromoKind.volumeTier,
  ];

  PromoKind? _kind;

  /// Read once per screen rather than per card, so every countdown on the page
  /// agrees and `build` stays free of clock reads (FS-PRF-7).
  late final DateTime _now = widget.now ?? DateTime.now();

  late List<PromoView> _all = widget.promotions ?? mockOutletPromotions;

  late List<PromoView> _sorted = _sortPromos(_all);

  List<PromoView> _sortPromos(List<PromoView> list) {
    return [...list]..sort((a, b) {
        final aLive = a.isQuotable(_now);
        final bLive = b.isQuotable(_now);
        if (aLive != bLive) return aLive ? -1 : 1;
        return a.endsOn.compareTo(b.endsOn);
      });
  }

  @override
  void initState() {
    super.initState();
    _fetchPromotionsIfNeeded();
  }

  Future<void> _fetchPromotionsIfNeeded() async {
    if (widget.promotions != null ||
        widget.depotId == null ||
        widget.depotId!.isEmpty) {
      return;
    }
    if (!GetIt.I.isRegistered<GetDepotPromotions>()) {
      return;
    }
    final result = await GetIt.I<GetDepotPromotions>()(
      DepotPromotionsParams(widget.depotId!),
    );
    if (!mounted) return;
    result.when(
      success: (promos) {
        if (promos.isNotEmpty) {
          setState(() {
            _all = promos;
            _sorted = _sortPromos(promos);
          });
        }
      },
      failure: (_) {
        // Fall back gracefully
      },
    );
  }

  List<PromoView> get _visible =>
      _kind == null ? _sorted : _sorted.where((p) => p.kind == _kind).toList();

  int _countOf(PromoKind kind) => _all.where((p) => p.kind == kind).length;

  @override
  Widget build(BuildContext context) => LocalizedBuilder(builder: _build);

  Widget _build(BuildContext context) {
    final colors = context.appColors;
    final visible = _visible;
    final quotable = _sorted.where((p) => p.isQuotable(_now)).length;

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(
        backgroundColor: colors.canvas,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: context.rh(60),
        iconTheme:
            IconThemeData(color: colors.textPrimary, size: context.rr(24)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'promotions.title'.tr,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: context.rsp(17),
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: context.rh(2)),
            Text(
              // The outlet name when there is one, and otherwise the count of
              // what is actually usable — never a blank second line, which
              // would make the title bar change height between entries.
              widget.outletName ??
                  'promotions.quotable_count'.trParams({'count': '$quotable'}),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: context.rsp(11.5),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: ResponsiveContentFrame(
          child: Column(
            children: [
              SizedBox(height: context.rh(4)),
              PromoFilterBar<PromoKind>(
                selected: _kind,
                onChanged: (kind) => setState(() => _kind = kind),
                options: [
                  PromoFilterOption(
                    value: null,
                    label: 'promotions.filter.all'.tr,
                    count: _all.length,
                    icon: Icons.apps_rounded,
                  ),
                  // The three mechanisms a depot can be offered (BRD §6.1),
                  // fixed rather than derived from the data. A bar whose
                  // options appear and vanish as promotions expire gives the
                  // rep no stable place to tap; a mechanism with none left
                  // still renders, disabled, and its zero is the answer.
                  for (final kind in _offeredKinds)
                    PromoFilterOption(
                      value: kind,
                      label: promoToneFor(context, kind).labelKey.tr,
                      count: _countOf(kind),
                      icon: promoToneFor(context, kind).icon,
                    ),
                ],
              ),
              SizedBox(height: context.rh(8)),
              Expanded(
                child: visible.isEmpty
                    ? _EmptyState(filtered: _kind != null)
                    : _PromoList(promos: visible, now: _now),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The list itself, kept separate so the screen's own build stays readable.
class _PromoList extends StatelessWidget {
  const _PromoList({required this.promos, required this.now});

  final List<PromoView> promos;
  final DateTime now;

  /// Entrance stagger stops after this many cards. Past roughly six the
  /// cascade stops reading as polish and starts reading as a slow list
  /// (FS-ANI-6).
  static const _maxStaggered = 6;

  /// The narrowest a promotion card may be laid out at.
  ///
  /// The card is composed horizontally — value tile, then body — so squeezing
  /// it does not shorten the text, it starves the body. Derived on device: at
  /// 600pt the size class is already `medium`, which multiplies every box by
  /// 1.30, so a naive two-column split left the body about 60pt wide and the
  /// metadata chips overflowed their own row.
  static const _minCardWidth = 340.0;

  @override
  Widget build(BuildContext context) {
    // Columns come from the width actually available, not from the size class
    // (FS-RSP-4). Keying off `medium` put the second column in at exactly
    // 600pt, which is a real device width and far too narrow for two of these
    // — the precise failure mode FS-RSP-6 warns about.
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth - 2 * context.pagePadding;
        final columns =
            (available / context.rw(_minCardWidth)).floor().clamp(1, 3);
        return _buildList(context, columns);
      },
    );
  }

  Widget _buildList(BuildContext context, int columns) {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        context.pagePadding,
        context.rh(6),
        context.pagePadding,
        context.rh(24),
      ),
      itemCount: (promos.length / columns).ceil(),
      separatorBuilder: (_, __) => SizedBox(height: context.rh(12)),
      itemBuilder: (context, rowIndex) {
        final row = promos.skip(rowIndex * columns).take(columns).toList();

        final content = columns == 1
            ? PromoCard(promo: row.first, now: now)
            : Row(
                // Top-aligned, not stretched: a `Row` inside a `ListView` item
                // has no bounded height to stretch into, so cross-axis stretch
                // is a layout assertion rather than an alignment. Cards in a
                // row differ in height anyway — a summary line here, none
                // there — and forcing them equal would only add whitespace.
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < columns; i++) ...[
                    if (i != 0) SizedBox(width: context.rw(12)),
                    Expanded(
                      child: i < row.length
                          ? PromoCard(promo: row[i], now: now)
                          // Holds the last row's column width so a lone final
                          // card does not stretch to twice its neighbours'.
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              );

        return FadeSlideIn(
          key: ValueKey(row.first.id),
          delay: AppDurations.stagger * (rowIndex.clamp(0, _maxStaggered)),
          child: content,
        );
      },
    );
  }
}

/// What the rep sees when there is nothing to show — which is a state that says
/// what to do next, not a bare sentence in grey (FS-UX-1).
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filtered});

  /// Distinguishes "this depot has no promotions" from "your filter has no
  /// promotions". They call for different next actions, and the old screen said
  /// the same thing for both.
  final bool filtered;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(context.pagePadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.local_offer_rounded,
              size: context.rr(44),
              color: colors.iconMuted,
            ),
            SizedBox(height: context.rh(14)),
            Text(
              filtered
                  ? 'promotions.empty.filtered_title'.tr
                  : 'promotions.empty.title'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: context.rsp(15),
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: context.rh(6)),
            Text(
              filtered
                  ? 'promotions.empty.filtered_body'.tr
                  : 'promotions.empty.body'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: context.rsp(13),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
