import 'package:equatable/equatable.dart';

/// Where one material's price currently stands.
///
/// Per material, never per screen. A quotation with four lines can legitimately
/// be showing four different states at once — one live, one loading, one
/// unavailable, one stale — and collapsing them into a single screen-level
/// status would make three of the four lie.
enum PricingState {
  /// Never asked. The material has just been selected and the request has not
  /// gone out yet.
  initial,

  /// In flight. Only this card shows a spinner; the rest of the quotation
  /// stays usable.
  loading,

  /// A price arrived from the backend and is current.
  loaded,

  /// A newer price arrived over the realtime hub. Rendered like [loaded] plus
  /// a brief "price updated" acknowledgement, because a number changing under
  /// a rep mid-conversation needs to be seen changing.
  updated,

  /// The backend answered, and the answer is that there is no price for this
  /// depot and material. A definite negative, not a failure.
  unavailable,

  /// The request failed. Distinct from [unavailable]: this one is retryable,
  /// and the card offers a retry rather than a shrug.
  error,

  /// The realtime connection dropped and is being re-established. The last
  /// known price is still shown, marked as no longer live.
  reconnecting,
}

/// Why a price could not be fetched.
///
/// The spec asks for these to be distinguished rather than flattened, and the
/// reason is operational: "you are offline" sends a rep to find signal,
/// "this depot is not priceable" sends them to the office, and
/// "unauthorized" sends them to IT. One generic error message sends them
/// nowhere.
enum PricingErrorKind {
  none,
  noPrice,
  unauthorized,
  depotNotFound,
  depotNotPriceable,
  backendUnavailable,
  networkUnavailable,
  unknown,
}

/// One depot-specific price for one material, exactly as the backend
/// returned it.
///
/// **Nothing in this class computes a price.** The amount, the currency and the
/// validity window are transcribed from the pricing service; SAP's conditions
/// are not re-derived on the handset, and there is no fallback that quietly
/// substitutes a catalogue figure when the live one is missing. A quoted price
/// a depot can hold a rep to has exactly one source.
class MobilePrice extends Equatable {
  const MobilePrice({
    required this.material,
    required this.state,
    this.price,
    this.currency = '',
    this.validFrom,
    this.validTo,
    this.updatedAt,
    this.errorKind = PricingErrorKind.none,
    this.isStale = false,
  });

  /// The material has been selected but nothing has been asked yet.
  const MobilePrice.initial(this.material)
      : state = PricingState.initial,
        price = null,
        currency = '',
        validFrom = null,
        validTo = null,
        updatedAt = null,
        errorKind = PricingErrorKind.none,
        isStale = false;

  const MobilePrice.loading(this.material)
      : state = PricingState.loading,
        price = null,
        currency = '',
        validFrom = null,
        validTo = null,
        updatedAt = null,
        errorKind = PricingErrorKind.none,
        isStale = false;

  final String material;
  final PricingState state;

  /// The amount, or null when there is none to show.
  ///
  /// Null rather than `0.0`, and the distinction is the whole point: zero is a
  /// quoted price a depot can hold the rep to, and "we do not have one yet"
  /// is not a number at all.
  final double? price;

  final String currency;
  final DateTime? validFrom;
  final DateTime? validTo;

  /// The backend's own stamp for this price.
  ///
  /// The ordering key for realtime updates: a hub event older than what is
  /// already on screen is dropped rather than applied, so a delayed packet
  /// cannot walk a price backwards. See `PricingCubit`.
  final DateTime? updatedAt;

  final PricingErrorKind errorKind;

  /// The price is real but no longer known to be current — the connection
  /// dropped, or it came from a cache while offline.
  ///
  /// Shown as a price *with a caveat* rather than hidden: a rep quoting from
  /// last known data is a normal field situation, and pretending the number is
  /// live would be the actual harm.
  final bool isStale;

  bool get hasAmount => price != null && price! > 0;

  /// Whether the card should show a spinner rather than a figure.
  bool get isBusy =>
      state == PricingState.loading || state == PricingState.initial;

  /// Whether a retry is worth offering. [PricingState.unavailable] is a
  /// settled answer and retrying it just asks the same question again.
  bool get isRetryable => state == PricingState.error;

  /// True while the price is known to be current — used for the "● Live price"
  /// indicator, which must not appear over a stale or reconnecting figure.
  bool get isLive =>
      !isStale &&
      (state == PricingState.loaded || state == PricingState.updated);

  MobilePrice copyWith({
    PricingState? state,
    double? Function()? price,
    String? currency,
    DateTime? Function()? validFrom,
    DateTime? Function()? validTo,
    DateTime? Function()? updatedAt,
    PricingErrorKind? errorKind,
    bool? isStale,
  }) {
    return MobilePrice(
      material: material,
      state: state ?? this.state,
      price: price != null ? price() : this.price,
      currency: currency ?? this.currency,
      validFrom: validFrom != null ? validFrom() : this.validFrom,
      validTo: validTo != null ? validTo() : this.validTo,
      updatedAt: updatedAt != null ? updatedAt() : this.updatedAt,
      errorKind: errorKind ?? this.errorKind,
      isStale: isStale ?? this.isStale,
    );
  }

  @override
  List<Object?> get props => [
        material,
        state,
        price,
        currency,
        validFrom,
        validTo,
        updatedAt,
        errorKind,
        isStale,
      ];
}
