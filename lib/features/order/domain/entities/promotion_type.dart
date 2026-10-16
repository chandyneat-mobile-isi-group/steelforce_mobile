enum PromotionType {
  percentDiscount,
  buyXGetY,
  clearance,
  monthly;

  String defaultLabel({double? discountPercent, int? buyQty, int? getQty}) =>
      switch (this) {
        PromotionType.percentDiscount =>
          '${discountPercent?.toStringAsFixed(0) ?? ''}% Off',
        PromotionType.buyXGetY => 'Buy ${buyQty ?? 10} Get ${getQty ?? 1}',
        PromotionType.clearance => 'Clearance Sale',
        PromotionType.monthly => 'Monthly Promotion',
      };
}
