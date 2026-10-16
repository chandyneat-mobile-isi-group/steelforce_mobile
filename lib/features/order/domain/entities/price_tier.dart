/// Every non-promotional price a depot/deal type can be quoted at.
/// Kept distinct from MTO pricing ([MtoPricingService]), which never
/// resolves from this local table at all.
enum PriceTier {
  standard,
  wholesale,
  dealer,
  vip,
  credit,
  cash;

  String get label => switch (this) {
        PriceTier.standard => 'Standard',
        PriceTier.wholesale => 'Wholesale',
        PriceTier.dealer => 'Dealer',
        PriceTier.vip => 'VIP',
        PriceTier.credit => 'Credit',
        PriceTier.cash => 'Cash',
      };
}
