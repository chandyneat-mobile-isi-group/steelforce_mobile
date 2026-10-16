import 'package:equatable/equatable.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart' show ResultFuture;
import 'package:steelforce/features/order/domain/entities/price_tier.dart';
import 'package:steelforce/features/order/domain/repositories/product_repository.dart';

class OutletPriceParams extends Equatable {
  const OutletPriceParams({required this.skuId, this.priceGroup});

  /// `products.id` — one SKU at one warehouse. Price is per SKU, not per
  /// material: the same article can be priced differently by plant.
  final String skuId;

  /// SAP `Depot.priceGroup` for the outlet being quoted, or null for a
  /// walk-in / lead with no SAP identity yet.
  final String? priceGroup;

  @override
  List<Object?> get props => [skuId, priceGroup];
}

/// What one SKU costs this outlet, and on which tier.
class OutletPrice extends Equatable {
  const OutletPrice({
    required this.unitPrice,
    required this.tier,
    required this.currency,
    required this.isTierResolved,
  });

  final double unitPrice;
  final PriceTier tier;
  final String currency;

  /// False when [tier] is the fallback rather than the outlet's real tier —
  /// see [ResolveOutletPrice] for why that is currently always the case.
  final bool isTierResolved;

  @override
  List<Object?> get props => [unitPrice, tier, currency, isTierResolved];
}

/// The single place the app decides what an outlet pays for a SKU.
///
/// ## The integration boundary
///
/// The local catalog already carries all seven of SAP's price tiers per SKU
/// (`prices.standard_price`, `wholesale_price`, `dealer_price`, `vip_price`,
/// `credit_price`, `cash_price`, plus any promotion), and [Depot] carries
/// SAP's `priceGroup`. What the repository does **not** have is the mapping
/// between them — SAP has published no `priceGroup` → tier table, and this app
/// is not the system of record for that decision.
///
/// So this use case deliberately does not guess. It resolves against
/// [PriceTier.standard], the tier the app has always quoted, and reports
/// [OutletPrice.isTierResolved] as false so callers can see that the outlet's
/// own tier was not applied.
///
/// **To complete this, SAP needs to supply** either a `priceGroup` → tier
/// mapping, or (better) a per-outlet price lookup. When it does, only
/// [_tierFor] and the datasource behind it change: every caller already asks
/// this question through this one type, so nothing above it moves.
class ResolveOutletPrice extends UseCase<OutletPrice, OutletPriceParams> {
  const ResolveOutletPrice(this._products);

  final ProductRepository _products;

  @override
  ResultFuture<OutletPrice> call(OutletPriceParams params) async {
    final result = await _products.getProduct(params.skuId);
    return result.when(
      success: (sku) {
        final (tier, resolved) = _tierFor(params.priceGroup);
        return Success(OutletPrice(
          // `effectivePrice`, not `priceFor`: an active promotion beats the
          // tier, which is how the catalog has always priced and what the
          // product card on screen is showing.
          unitPrice: sku.pricing.effectivePrice(tier),
          tier: tier,
          currency: sku.pricing.currency,
          isTierResolved: resolved,
        ));
      },
      failure: Failed.new,
    );
  }

  /// Returns `(tier, wasResolved)`. Always unresolved today — see the class
  /// doc. Kept as a function rather than a constant so the eventual mapping
  /// has an obvious, single home.
  static (PriceTier, bool) _tierFor(String? priceGroup) =>
      (PriceTier.standard, false);
}
