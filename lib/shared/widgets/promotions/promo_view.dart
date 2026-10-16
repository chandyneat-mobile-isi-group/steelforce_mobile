import 'package:flutter/foundation.dart';

/// The promotion mechanisms a depot can be offered.
///
/// **Not the same thing as `features/order/domain/entities/promotion/`.** That
/// `Promotion` is a free-goods ladder evaluated against a cart line's quantity,
/// and its own doc is emphatic that it "is *not* a price… carries no amount and
/// no currency". These are the depot discount *schemes* of the Promotions BRD —
/// percentages and rebates against an invoice, each with a four-step approval
/// trail behind it. Two different objects that the business calls by the same
/// word; conflating them would put a rate where a quantity ladder belongs.
///
/// The one place they touch is [PromoKind.buyXGetY]. When the promotions data
/// layer lands, that case should read from `PromotionRepository` rather than
/// carry its own numbers.
///
/// Mirrors `PROMOTION_TYPE` in the Promotions BRD §6.1, plus the two shapes the
/// quotation screen shows alongside it (a depot's own pending request, and a
/// buy-X-get-Y goods promotion). Presentation-level on purpose: the real
/// entities land with the data layer, and building them now would jump ahead of
/// the migration plan (`.claude/CLAUDE.md` §1).
enum PromoKind {
  /// Discount deducted on the invoice itself. BRD: `ON_INVOICE`.
  onInvoice,

  /// Discount earned by paying cash on delivery or collecting from the depot.
  /// BRD: `PAYMENT_TERM` ("Immediate-Payment Discount").
  paymentTerm,

  /// Rebate whose rate depends on the month's purchase volume. BRD: tiered
  /// `promotion_tier` rows on a request line.
  volumeTier,

  /// Free goods rather than money off — "buy 40 bags, get 3".
  buyXGetY,

  /// A discount the depot has asked for, somewhere in the four-step approval
  /// chain (BRD §8). Not yet money the rep can quote.
  depotRequest,
}

/// A condition the order itself must satisfy before a promotion applies.
///
/// Separate from [PromoStatus]: an approved, in-date, perfectly valid
/// promotion can still be unusable on *this* quotation because of how the
/// goods are moving. Modelled as a set rather than a boolean so the BRD's other
/// conditions (minimum spend, FR-03's volume tiers) have somewhere to land.
enum PromoRequirement {
  /// The depot must collect from the depot.
  ///
  /// Deliberately **not** satisfied by the COD toggle. The promotion reads
  /// "COD / Pickup" and the BRD calls the mechanism an "Immediate-Payment
  /// Discount", both of which suggest cash-on-delivery should qualify — ISI
  /// confirmed it does not. Delivery loses the discount whatever the payment
  /// terms, so the shipment method is the only input.
  pickup,
}

/// What the quotation currently looks like, as far as promotions care.
///
/// Deliberately not `ShipmentMethod` from the order feature: this widget set is
/// shared, and importing a feature's presentation enum into `shared/` would
/// invert the dependency (FS-SCL-2). The quotation builder maps its own state
/// onto this at the call site, which is one line and keeps the direction right.
@immutable
class OrderTerms {
  const OrderTerms({required this.isPickup});

  /// True when the goods are being collected rather than delivered.
  final bool isPickup;

  bool satisfies(PromoRequirement requirement) => switch (requirement) {
        PromoRequirement.pickup => isPickup,
      };
}

/// Where a promotion sits in the BRD §8 approval chain, reduced to what a rep
/// on a forecourt actually needs to know: can I quote this today or not.
enum PromoStatus { active, approved, pending, expired }

/// How a promotion's headline number reads.
///
/// Sealed so the value tile must handle every shape — the old screens each
/// pre-formatted a `discountLabel` string at the call site, which is how
/// "5% OFF", "$10/Ton" and "Special Rate" ended up rendered in three different
/// type sizes on cards sitting next to each other.
@immutable
sealed class PromoValue {
  const PromoValue();

  factory PromoValue.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String? ?? '';
    switch (type) {
      case 'percent':
        return PromoPercent((json['percent'] as num?)?.toDouble() ?? 0.0);
      case 'amount':
        return PromoAmount(
          json['amount']?.toString() ?? '',
          per: json['per'] as String?,
        );
      case 'buyGet':
        return PromoBuyGet(
          buy: json['buy'] as int? ?? 0,
          get: json['get'] as int? ?? 0,
          unit: json['unit'] as String? ?? '',
        );
      case 'terms':
      default:
        return PromoTerms(json['text'] as String? ?? '');
    }
  }
}

/// A percentage off, e.g. `2.0` → "2.00 %".
class PromoPercent extends PromoValue {
  const PromoPercent(this.percent);
  final double percent;
}

/// A fixed sum, already formatted by whoever owns the currency (BRD amounts are
/// USD `NUMERIC(14,2)`). [per] is the unit it is earned against, e.g. "Ton".
class PromoAmount extends PromoValue {
  const PromoAmount(this.amount, {this.per});
  final String amount;
  final String? per;
}

/// Free goods: buy [buy] [unit], get [get] free.
class PromoBuyGet extends PromoValue {
  const PromoBuyGet({required this.buy, required this.get, required this.unit});
  final int buy;
  final int get;
  final String unit;
}

/// A negotiated rate with no single number to show — "Special Rate". The text
/// is master data from SAP, not app chrome, so it is not a translation key.
class PromoTerms extends PromoValue {
  const PromoTerms(this.text);
  final String text;
}

/// How close a promotion is to running out, which is the one thing about a
/// promotion that changes what a rep does today.
enum PromoUrgency {
  /// Past its end date — shown, but never as something to quote.
  expired,

  /// A week or less. Worth mentioning on this visit.
  urgent,

  /// A month or less.
  soon,

  /// Far enough out that the date is just a fact.
  normal,
}

/// A promotion as a screen needs it.
///
/// Deliberately carries `DateTime` rather than the pre-rendered date strings the
/// old screens held ('31 Aug 2026'). A string cannot answer "is this about to
/// expire", which turned out to be the only question the rep was really asking
/// of that field.
@immutable
class PromoView {
  const PromoView({
    required this.id,
    required this.title,
    required this.kind,
    required this.value,
    required this.status,
    required this.endsOn,
    this.code,
    this.summary,
    this.startsOn,
    this.minSpend,
    this.category,
    this.depots,
    this.requires = const {},
  });

  factory PromoView.fromJson(Map<String, dynamic> json) {
    final kindStr = json['kind'] as String? ?? 'onInvoice';
    final kind = PromoKind.values.firstWhere(
      (k) => k.name.toLowerCase() == kindStr.toLowerCase(),
      orElse: () => PromoKind.onInvoice,
    );

    final statusStr = json['status'] as String? ?? 'active';
    final status = PromoStatus.values.firstWhere(
      (s) => s.name.toLowerCase() == statusStr.toLowerCase(),
      orElse: () => PromoStatus.active,
    );

    final rawRequires = json['requires'] as List<dynamic>? ?? const [];
    final requires = rawRequires
        .map((r) => r.toString().toLowerCase())
        .map((r) => r == 'pickup' ? PromoRequirement.pickup : null)
        .whereType<PromoRequirement>()
        .toSet();

    final valueMap = json['value'] as Map<String, dynamic>? ?? {};

    return PromoView(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      summary: json['summary'] as String?,
      code: json['code'] as String?,
      kind: kind,
      value: PromoValue.fromJson(valueMap),
      status: status,
      startsOn: json['startsOn'] != null
          ? DateTime.tryParse(json['startsOn'] as String)
          : null,
      endsOn: json['endsOn'] != null
          ? DateTime.tryParse(json['endsOn'] as String) ?? DateTime.now()
          : DateTime.now(),
      minSpend: json['minSpend']?.toString(),
      category: json['category'] as String?,
      depots: json['customers'] as String?,
      requires: requires,
    );
  }

  final String id;

  /// Master data from SAP — not localized. See [PromoTerms].
  final String title;
  final String? summary;

  /// The human-readable promo code (`request_no` in BRD §7.2). Null when the
  /// scheme has no code for the rep to quote.
  final String? code;

  final PromoKind kind;
  final PromoValue value;
  final PromoStatus status;

  final DateTime? startsOn;
  final DateTime endsOn;

  final String? minSpend;
  final String? category;
  final String? depots;

  /// Conditions the order must meet. Empty — the common case — means the
  /// promotion applies however the quotation is set up.
  final Set<PromoRequirement> requires;

  /// Whole days from [now] until this stops applying; negative once expired.
  ///
  /// Computed from local midnights and rounded from hours rather than taken
  /// from `Duration.inDays`, because a DST boundary between the two dates makes
  /// the raw difference 23 or 25 hours and truncates to the wrong day count —
  /// the kind of off-by-one that shows a rep "ends in 0 days" the morning
  /// before it really ends.
  int daysLeft(DateTime now) {
    final end = DateTime(endsOn.year, endsOn.month, endsOn.day);
    final today = DateTime(now.year, now.month, now.day);
    return (end.difference(today).inHours / 24).round();
  }

  PromoUrgency urgency(DateTime now) {
    if (status == PromoStatus.expired) return PromoUrgency.expired;
    final days = daysLeft(now);
    if (days < 0) return PromoUrgency.expired;
    if (days <= 7) return PromoUrgency.urgent;
    if (days <= 30) return PromoUrgency.soon;
    return PromoUrgency.normal;
  }

  /// True when the rep can quote this to the depot right now.
  bool isQuotable(DateTime now) =>
      status == PromoStatus.active && urgency(now) != PromoUrgency.expired;

  /// The first requirement [terms] does not meet, or null when the promotion
  /// applies.
  ///
  /// Returns the *reason* rather than a bool because the rep needs to be told
  /// which one it is. A discount that simply disappears when they change the
  /// shipment method reads as a defect, and leaves them no way back to it.
  ///
  /// A null [terms] means the caller has no order to judge against — the outlet
  /// promotions list, for instance, which shows what a depot is entitled to
  /// rather than what one quotation currently earns. Nothing is blocked there.
  PromoRequirement? unmetRequirement(OrderTerms? terms) {
    if (terms == null) return null;
    for (final requirement in requires) {
      if (!terms.satisfies(requirement)) return requirement;
    }
    return null;
  }

  /// True when this promotion can be applied to an order with [terms].
  bool isAvailableFor(DateTime now, OrderTerms? terms) =>
      isQuotable(now) && unmetRequirement(terms) == null;
}

/// One labelled group of promotions, as the quotation builder lists them.
class PromoGroup {
  const PromoGroup({
    required this.titleKey,
    required this.promos,
  });

  factory PromoGroup.fromJson(Map<String, dynamic> json) {
    final rawPromos = json['promos'] as List<dynamic>? ?? const [];
    return PromoGroup(
      titleKey: json['titleKey'] as String? ??
          (json['groupId'] != null
              ? 'promotions.group.${json['groupId']}'
              : 'promotions.group.depot_discount'),
      promos: rawPromos
          .whereType<Map>()
          .map((m) => PromoView.fromJson(m.cast<String, dynamic>()))
          .toList(),
    );
  }

  /// Translation key for the group heading.
  final String titleKey;
  final List<PromoView> promos;
}
