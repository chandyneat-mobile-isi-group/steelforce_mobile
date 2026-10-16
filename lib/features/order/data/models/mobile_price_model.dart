import 'package:steelforce/core/network/api/api_envelope.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/domain/entities/mobile_price.dart';

/// Wire → domain for the pricing surface.
///
/// One row of `GET /mobile/pricing/depots/{id}`:
///
/// ```jsonc
/// { "material": "1100000000", "price": 1250.50, "currency": "USD",
///   "validFrom": "2026-01-01T00:00:00Z", "validTo": "2026-12-31T00:00:00Z" }
/// ```
///
/// The same shape arrives inside a `PricingUpdated` hub event, so both paths
/// deserialise here rather than each growing its own parser and drifting.
abstract final class MobilePriceMapper {
  /// [updatedAt] is the event stamp for a realtime push, and null for a REST
  /// read. It is the ordering key that stops a delayed packet walking a price
  /// backwards, so it is carried rather than derived from arrival time — the
  /// handset clock is not the authority on when a price changed.
  static MobilePrice fromJson(DataMap json, {DateTime? updatedAt}) {
    final material = _string(json['material']);
    final amount = (json['price'] as num?)?.toDouble();

    // A row with no amount is a definite negative — the backend was asked and
    // answered "no price for this depot and material". That is settled, and
    // offering a retry for it would just ask the same question again.
    if (amount == null) {
      return MobilePrice(
        material: material,
        state: PricingState.unavailable,
        errorKind: PricingErrorKind.noPrice,
        updatedAt: updatedAt,
      );
    }

    return MobilePrice(
      material: material,
      state: updatedAt == null ? PricingState.loaded : PricingState.updated,
      price: amount,
      currency: _string(json['currency']),
      validFrom: parseUtc(json['validFrom']),
      validTo: parseUtc(json['validTo']),
      updatedAt: updatedAt,
    );
  }

  /// The `PricingUpdated` payload: `{ items: [...], updatedAt }`.
  ///
  /// The event's single `updatedAt` stamps every item in it — the server
  /// published them together, so they share an ordering position.
  static List<MobilePrice> fromUpdateEvent(DataMap json) {
    final stamp = parseUtc(json['updatedAt']) ?? DateTime.now().toUtc();
    return (json['items'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .map((item) => fromJson(item, updatedAt: stamp))
        .toList(growable: false);
  }

  static String _string(Object? raw) => raw is String ? raw.trim() : '';
}
