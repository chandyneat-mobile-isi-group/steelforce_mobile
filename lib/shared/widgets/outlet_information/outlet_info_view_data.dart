import 'package:equatable/equatable.dart';
import 'package:steelforce/core/localization/localized_text.dart';

/// Everything the shared outlet/depot detail layout renders, as plain data.
///
/// This exists so `my_visits` and `depots` can present the *same* screen
/// without either importing the other, and without the layout knowing that a
/// `DepotStopInfo` (the lean projection a route stop carries) and a
/// `Depot` (the full SAP master record) are different types with different
/// field names. Each feature maps its own entity onto this; the layout only
/// ever sees strings.
///
/// **Null means "this source has no such field", and the row is dropped.** It
/// does not mean "render an empty value" — a visit stop genuinely has no credit
/// limit, and a depot opened from the directory genuinely has no promotion
/// counts. Passing a placeholder string instead would invent data, which on a
/// screen a rep reads in front of the shop owner is worse than showing less.
class OutletInfoViewData extends Equatable {
  const OutletInfoViewData({
    required this.displayName,
    required this.code,
    this.outletId,
    this.outletType,
    this.outletTier,
    this.outletAction,
    this.contactPerson,
    this.assignedRep,
    this.phone,
    this.telegram,
    this.email,
    this.address,
    this.taxNumber,
    this.latitude,
    this.longitude,
    this.paymentStatus,
    this.creditLimit,
    this.paymentTerm,
    this.lifetimeValue,
    this.totalOrders,
    this.averageRevenuePerOrder,
    this.latestOrderDate,
    this.openOpportunities,
    this.lastSynced,
    this.promotions,
  });

  /// Shop name in both languages; the layout resolves it against the locale.
  final LocalizedText displayName;

  /// Rendered in the hero card's "CUS CODE" chip.
  final String code;

  // ── Outlet Details & Location ──────────────────────────────────────────
  final String? outletId;
  final String? outletType;
  final String? outletTier;
  final String? outletAction;
  final String? contactPerson;
  final String? assignedRep;
  final String? phone;
  final String? telegram;
  final String? email;
  final String? address;
  final String? taxNumber;

  /// Both must be present for the coordinate row and the map action to appear.
  /// `(0, 0)` is the app's "no GPS fix" encoding — a real point in the Gulf of
  /// Guinea — so callers must pass null rather than that pair, exactly as
  /// `hasCoordinates` guards every other geographic consumer.
  final double? latitude;
  final double? longitude;

  bool get hasCoordinates =>
      latitude != null &&
      longitude != null &&
      (latitude != 0 || longitude != 0);

  // ── Sales History Detail ───────────────────────────────────────────────
  final String? paymentStatus;
  final String? creditLimit;
  final String? paymentTerm;
  final String? lifetimeValue;
  final String? totalOrders;
  final String? averageRevenuePerOrder;
  final String? latestOrderDate;
  final String? openOpportunities;
  final String? lastSynced;

  /// Omitted entirely when the source has no promotion data, which drops the
  /// whole card rather than showing a card full of zeroes.
  final OutletPromotionSummary? promotions;

  /// Whether the Sales History card has anything to show. The layout drops the
  /// card rather than rendering a header over nothing.
  bool get hasSalesHistory =>
      paymentStatus != null ||
      creditLimit != null ||
      paymentTerm != null ||
      lifetimeValue != null ||
      totalOrders != null ||
      averageRevenuePerOrder != null ||
      latestOrderDate != null ||
      openOpportunities != null ||
      lastSynced != null;

  @override
  List<Object?> get props => [
        displayName,
        code,
        outletId,
        outletType,
        outletTier,
        outletAction,
        contactPerson,
        assignedRep,
        phone,
        telegram,
        email,
        address,
        taxNumber,
        latitude,
        longitude,
        paymentStatus,
        creditLimit,
        paymentTerm,
        lifetimeValue,
        totalOrders,
        averageRevenuePerOrder,
        latestOrderDate,
        openOpportunities,
        lastSynced,
        promotions,
      ];
}

/// Promotion counts for the outlet, as shown in the Promotions card.
class OutletPromotionSummary extends Equatable {
  const OutletPromotionSummary({
    required this.total,
    required this.onInvoice,
    required this.offInvoice,
    required this.contract,
  });

  /// The demo counts both detail screens currently show.
  ///
  /// Neither source has real promotion data yet: a route stop carries only
  /// [DepotStopInfo], and promotions are not part of the SAP depot master
  /// sync. These numbers have always been hardcoded on the stop screen; they
  /// live here as a single named constant so the two screens cannot drift to
  /// *different* fake numbers, and so there is exactly one thing to delete when
  /// the real feed lands.
  ///
  /// TODO(sap): replace with synced promotion counts and remove this constant.
  static const placeholder = OutletPromotionSummary(
    total: 25,
    onInvoice: 20,
    offInvoice: 0,
    contract: 5,
  );

  final int total;
  final int onInvoice;
  final int offInvoice;
  final int contract;

  @override
  List<Object?> get props => [total, onInvoice, offInvoice, contract];
}
