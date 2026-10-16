import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/features/order/domain/entities/mobile_price.dart';
import 'package:steelforce/features/order/domain/repositories/pricing_repository.dart';
import 'package:steelforce/features/order/domain/usecases/get_depot_material_prices.dart';

/// Live prices for the materials on this quotation, keyed by material code.
///
/// One entry per material, and that is the whole design: a quotation can
/// legitimately be showing one price live, one loading, one unavailable and
/// one stale at the same time. A screen-level pricing status would make three
/// of those four lie, and one failed material would blank the rest.
///
/// ## The stale-update rule
///
/// A realtime event carries the server's own `updatedAt`. An event older than
/// what is already on screen is **dropped**, never applied. Without that, a
/// delayed packet arriving after a newer one walks the price backwards — and a
/// rep who has already said a number out loud watches it change to an older
/// one for no visible reason.
///
/// ## The reconnect rule
///
/// Hub group membership does not survive a dropped connection, and the hub does
/// not replay what was missed. So a reconnect is not "resume listening": it is
/// re-fetch over REST *and* re-subscribe, in that order. Anything less quotes a
/// price that stopped being current while the socket was down.
class PricingCubit extends Cubit<Map<String, MobilePrice>> {
  PricingCubit({
    required GetDepotMaterialPrices getPrices,
    required PricingRealtimeSource realtime,
  })  : _getPrices = getPrices,
        _realtime = realtime,
        super(const {}) {
    _updateSub = _realtime.updates.listen(_onRealtimePrice);
    _reconnectSub = _realtime.reconnections.listen((_) => _onReconnected());
  }

  final GetDepotMaterialPrices _getPrices;
  final PricingRealtimeSource _realtime;

  StreamSubscription<MobilePrice>? _updateSub;
  StreamSubscription<void>? _reconnectSub;

  String? _depotId;

  /// Everything currently on the quotation, so a reconnect knows what to
  /// re-ask for without the UI having to tell it again.
  final Set<String> _tracked = {};
  final Set<String> _inFlight = {};

  String? get depotId => _depotId;

  MobilePrice? of(String material) => state[material];

  /// Points pricing at a depot, re-subscribing the hub.
  ///
  /// Changing depot drops every held price: they are quoted *per depot*,
  /// and leaving the previous shop's figures on screen would be both wrong and
  /// a disclosure. The old subscription is dropped before the new one is made,
  /// so the handset never sits in two pricing groups at once.
  Future<void> setDepot(String? depotId) async {
    if (_depotId == depotId) return;
    _depotId = depotId;
    emit(const {});

    if (kDebugMode) {
      debugPrint('[PricingCubit] setDepot: $depotId');
    }

    await _realtime.unsubscribe();
    if (depotId == null || depotId.isEmpty) return;
    await _realtime.subscribe(depotId);
    if (_tracked.isNotEmpty) await refresh();
  }

  /// Starts tracking [materials] and fetches any that have no price yet.
  ///
  /// Safe to call whenever the quotation's line-up changes: materials already
  /// priced are not re-asked, so adding an eighth line costs one request for
  /// that line rather than eight for all of them.
  Future<void> track(Iterable<String> materials) async {
    final fresh = materials
        .map((m) => m.trim())
        .where((m) => m.isNotEmpty && !_tracked.contains(m))
        .toSet();
    if (fresh.isEmpty) return;

    if (kDebugMode) {
      debugPrint(
          '[PricingCubit] track fresh materials: $fresh (depot: $_depotId)');
    }

    _tracked.addAll(fresh);
    await _fetch(fresh.toList());
  }

  /// Stops tracking a material — the line was removed from the quotation.
  void untrack(String material) {
    _tracked.remove(material);
    if (!state.containsKey(material)) return;
    emit({...state}..remove(material));
  }

  /// Re-asks for everything currently tracked.
  ///
  /// The mandatory first half of the reconnect sequence. Not the per-card
  /// retry — see [retry], which is the one a rep taps.
  Future<void> refresh() => _fetch(_tracked.toList());

  /// Re-asks for one material — the "tap to retry" behind a failed card.
  ///
  /// Deliberately not [refresh]: a rep retrying one line must not put every
  /// other price on the quotation back into a spinner, and one material's
  /// failure is not a reason to re-ask about seven that answered fine.
  ///
  /// A material no longer on the quotation is ignored rather than fetched, so
  /// a retry racing a line removal cannot resurrect the card.
  Future<void> retry(String material) {
    if (!_tracked.contains(material)) return Future.value();
    return _fetch([material]);
  }

  Future<void> _fetch(List<String> materials) async {
    if (materials.isEmpty) return;
    final depotId = _depotId;

    if (depotId == null || depotId.isEmpty) {
      // A walk-in has nothing to price against. Settled, not broken — the card
      // says so and offers no retry, because retrying asks the same question.
      emit({
        ...state,
        for (final material in materials)
          material: MobilePrice(
            material: material,
            state: PricingState.unavailable,
            errorKind: PricingErrorKind.depotNotFound,
          ),
      });
      return;
    }

    // Skip materials that are already in flight to avoid duplicate concurrent calls.
    final toFetch = materials.where((m) => !_inFlight.contains(m)).toList();
    if (toFetch.isEmpty) return;

    _inFlight.addAll(toFetch);

    // Only the cards being fetched show a spinner. The rest of the quotation,
    // and every other price on it, stays exactly as it was.
    emit({
      ...state,
      for (final material in toFetch) material: MobilePrice.loading(material),
    });

    if (kDebugMode) {
      debugPrint('[PricingCubit] _fetch: depotId=$depotId, materials=$toFetch');
    }

    try {
      final result = await _getPrices(DepotPricesParams(
        depotId: depotId,
        materials: toFetch,
      ));
      if (isClosed) return;

      result.when(
        success: (prices) {
          if (kDebugMode) {
            debugPrint(
                '[PricingCubit] _fetch success: ${prices.length} prices received');
          }
          final next = {...state};
          for (final price in prices) {
            // A material dropped from the quotation while its request was in
            // flight must not reappear on screen.
            if (!_tracked.contains(price.material)) continue;
            next[price.material] = price;
          }
          emit(next);
        },
        failure: (failure) {
          if (kDebugMode) {
            debugPrint('[PricingCubit] _fetch failure: ${failure.message}');
          }
          final next = {...state};
          for (final material in toFetch) {
            if (!_tracked.contains(material)) continue;
            next[material] = MobilePrice(
              material: material,
              state: PricingState.error,
              errorKind: PricingErrorKind.unknown,
            );
          }
          emit(next);
        },
      );
    } finally {
      _inFlight.removeAll(toFetch);
    }
  }

  /// Applies a pushed price, unless it is older than what is already held.
  void _onRealtimePrice(MobilePrice incoming) {
    if (isClosed) return;
    if (!_tracked.contains(incoming.material)) return;

    final held = state[incoming.material];
    final heldStamp = held?.updatedAt;
    final incomingStamp = incoming.updatedAt;

    // The stale guard. Strictly newer wins; equal stamps are the same
    // publication arriving twice and change nothing.
    if (heldStamp != null &&
        incomingStamp != null &&
        !incomingStamp.isAfter(heldStamp)) {
      return;
    }

    emit({...state, incoming.material: incoming});
  }

  /// The reconnect sequence: REST first, then resume.
  ///
  /// The hub does not replay what was missed while the socket was down, so
  /// whatever is on screen is of unknown age until REST says otherwise.
  Future<void> _onReconnected() async {
    if (isClosed) return;
    final depotId = _depotId;
    if (depotId == null || depotId.isEmpty) return;

    await _realtime.subscribe(depotId);
    if (isClosed) return;
    await refresh();
  }

  /// Marks every held price as no longer known to be current.
  ///
  /// Called when the transport drops. The figures stay on screen — a rep
  /// mid-conversation should not watch prices vanish — but they lose the live
  /// indicator, which is the honest rendering of "this was true a moment ago".
  void markStale() {
    if (state.isEmpty) return;
    emit({
      for (final entry in state.entries)
        entry.key: entry.value.copyWith(
          isStale: true,
          state: entry.value.hasAmount
              ? PricingState.reconnecting
              : entry.value.state,
        ),
    });
  }

  @override
  Future<void> close() {
    _updateSub?.cancel();
    _reconnectSub?.cancel();
    return super.close();
  }
}
