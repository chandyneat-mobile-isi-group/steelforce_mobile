import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/features/order/domain/entities/material_availability.dart';
import 'package:steelforce/features/order/domain/usecases/check_material_availability.dart';

/// Stock verdicts, keyed by SAP material number.
///
/// The state is a map rather than a single verdict because the endpoint is
/// per-material: `/materials/{material}/stock`. A single field shared across a
/// product list paints one material's band and base unit onto every row, which
/// is how a rep ends up reading "High · KG" against a material nobody asked
/// about.
///
/// An absent key means *never asked*, which the card renders as nothing at all.
/// That is the intended resting state for a scrolling list — the check is a
/// live ERP round trip, spent when a rep commits to a material, not on every
/// card that passes the viewport.
class StockCubit extends Cubit<Map<String, MaterialAvailability>> {
  StockCubit(this._check) : super(const {});

  final CheckMaterialAvailability _check;

  /// Requests in flight, so a rebuild mid-request does not fire a second one.
  final Set<String> _inFlight = {};

  /// How long a verdict stands before it is worth another round trip. Stock
  /// moves; a band read twenty minutes ago is a guess wearing a badge.
  static const _freshFor = Duration(minutes: 5);

  MaterialAvailability? of(String material) => state[material];

  /// Asks SAP about [material] unless a fresh answer is already held or a
  /// request is already out.
  Future<void> ensure(String material, {bool force = false}) async {
    if (material.isEmpty || _inFlight.contains(material)) return;
    if (!force && _isFresh(state[material])) return;

    _inFlight.add(material);
    _put(material, MaterialAvailability.checking(material));

    final result = await _check(MaterialAvailabilityParams(material));
    _inFlight.remove(material);
    if (isClosed) return;

    result.when(
      success: (verdict) => _put(material, verdict),
      failure: (_) => _put(material, _unknown(material)),
    );
  }

  /// Drops everything — call on depot switch or catalog sync, when the held
  /// verdicts describe a sales context that no longer applies.
  void invalidate() {
    _inFlight.clear();
    emit(const {});
  }

  /// A failed round trip is not a refusal.
  ///
  /// [MaterialStockStatus.unknown] keeps [MaterialAvailability.canOrder] true,
  /// so the quantity stepper stays live. Mapping a dropped connection to
  /// `unavailable` would decline a sale on the strength of a network error, and
  /// `isSellable: false` here is only ever read through `status`.
  MaterialAvailability _unknown(String material) => MaterialAvailability(
        material: material,
        isSellable: false,
        summary: '',
        status: MaterialStockStatus.unknown,
      );

  void _put(String material, MaterialAvailability verdict) =>
      emit({...state, material: verdict});

  bool _isFresh(MaterialAvailability? verdict) {
    if (verdict == null) return false;
    if (verdict.status == MaterialStockStatus.checking) return true;
    final at = verdict.checkedAt;
    if (at == null) return false;
    return DateTime.now().toUtc().difference(at.toUtc()) < _freshFor;
  }
}
