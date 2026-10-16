import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/features/order/domain/entities/promotion/promotion_evaluation.dart';
import 'package:steelforce/features/order/domain/usecases/evaluate_promotion.dart';

/// Per-material promotion verdicts for the product list, keyed by material
/// code.
///
/// Sits above the grid so every card reads the same map, the way [StockCubit]
/// does for sellability. Two things it is careful about, both of them the
/// difference between a promotion that helps and one that janks the list:
///
///  * **Quantity-driven, so it re-asks.** The verdict for 280 is not the
///    verdict for 300 — that is the entire feature. A change of quantity
///    invalidates the entry rather than reusing it.
///  * **Debounced per material.** A rep holding `+` walks through forty
///    quantities; asking for forty verdicts would be forty round trips once
///    this is served by an API. Only the quantity they stop on is asked about.
class PromotionCubit extends Cubit<Map<String, PromotionEvaluation>> {
  PromotionCubit({required EvaluatePromotion evaluate})
      : _evaluate = evaluate,
        super(const {});

  final EvaluatePromotion _evaluate;

  /// Matches the quantity stepper's own commit debounce, so the two settle
  /// together rather than the promotion trailing a beat behind the number.
  static const _debounce = Duration(milliseconds: 220);

  final Map<String, Timer> _pending = {};

  /// The quantity each material's held verdict was computed for, so a repeat
  /// call at the same quantity costs nothing.
  final Map<String, int> _askedFor = {};

  String? _depotId;

  /// The depot the quotation is for.
  ///
  /// Changing it drops every held verdict: entitlements are per depot, and
  /// showing the previous shop's negotiated deal against the new one would be
  /// both wrong and a leak.
  void setDepot(String? depotId) {
    if (_depotId == depotId) return;
    _depotId = depotId;
    _askedFor.clear();
    for (final timer in _pending.values) {
      timer.cancel();
    }
    _pending.clear();
    emit(const {});
  }

  PromotionEvaluation? of(String materialCode) => state[materialCode];

  /// Asks what [materialCode] earns at [quantity], debounced.
  ///
  /// Safe to call on every rebuild and every keystroke: a repeat at a quantity
  /// already answered returns without scheduling anything.
  void evaluate({
    required String materialCode,
    required String categoryCode,
    required int quantity,
  }) {
    if (materialCode.isEmpty) return;
    if (_askedFor[materialCode] == quantity) return;

    _pending[materialCode]?.cancel();
    _pending[materialCode] = Timer(_debounce, () {
      _pending.remove(materialCode);
      unawaited(_resolve(
        materialCode: materialCode,
        categoryCode: categoryCode,
        quantity: quantity,
      ));
    });
  }

  Future<void> _resolve({
    required String materialCode,
    required String categoryCode,
    required int quantity,
  }) async {
    if (isClosed) return;
    _askedFor[materialCode] = quantity;

    final result = await _evaluate(EvaluatePromotionParams(
      materialCode: materialCode,
      categoryCode: categoryCode,
      quantity: quantity,
      depotId: _depotId,
    ));
    if (isClosed) return;

    result.when(
      success: (evaluation) {
        final next = {...state};
        if (evaluation == null) {
          next.remove(materialCode);
        } else {
          next[materialCode] = evaluation;
        }
        emit(next);
      },
      // A failed lookup holds nothing rather than clearing what is shown: a
      // dropped request must not make a promotion the rep has already quoted
      // blink out mid-conversation.
      failure: (_) => _askedFor.remove(materialCode),
    );
  }

  @override
  Future<void> close() {
    for (final timer in _pending.values) {
      timer.cancel();
    }
    _pending.clear();
    return super.close();
  }
}
