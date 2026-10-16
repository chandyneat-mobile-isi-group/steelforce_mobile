import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/domain/entities/mobile_price.dart';

/// Depot-specific prices, live from the backend.
///
/// The backend is the only authority. Nothing behind this interface computes a
/// price, applies a condition, or falls back to a catalogue figure when the
/// live one is missing — a quoted amount has exactly one source, and a
/// plausible-looking local substitute is worse than an honest absence.
abstract interface class PricingRepository {
  /// Prices for [materials] as quoted to [depotId].
  ///
  /// Batched deliberately: the endpoint takes a repeatable `materials`
  /// parameter, so a quotation with eight lines costs one round trip rather
  /// than eight. Materials the backend returns no price for come back as
  /// [PricingState.unavailable] rather than being omitted, so a caller can
  /// tell "no price" from "never asked".
  ResultFuture<List<MobilePrice>> getPrices({
    required String depotId,
    required List<String> materials,
  });
}

/// The realtime half: a subscription to one depot's prices.
///
/// Separated from [PricingRepository] because the two have nothing in common
/// operationally. One is a request that completes; the other is a connection
/// that drops, reconnects and loses its group membership when it does.
///
/// **Group membership does not survive a reconnect.** The contract is
/// therefore: on every reconnect, re-fetch over REST *and* re-subscribe. The
/// hub does not replay what was missed, so a client that only re-subscribes
/// silently quotes a stale price.
abstract interface class PricingRealtimeSource {
  /// Prices pushed by the server, already mapped to the material they concern.
  ///
  /// Emits per material rather than per batch so one card updates without the
  /// others rebuilding.
  Stream<MobilePrice> get updates;

  /// Fires when the transport reconnects, which is the caller's cue to
  /// re-fetch over REST before trusting anything on screen again.
  Stream<void> get reconnections;

  /// Whether the transport is currently carrying updates. False makes every
  /// price on screen stale rather than wrong.
  bool get isConnected;

  /// Subscribes to [depotId]'s pricing group.
  ///
  /// The **depot id** goes on the wire, never a group name assembled on the
  /// handset: the server decides which group a depot belongs to, and a
  /// client that guesses will silently receive nothing the day that mapping
  /// changes.
  Future<void> subscribe(String depotId);

  /// Drops the current subscription. Called before subscribing to a different
  /// depot, so a rep switching shops does not keep receiving the previous
  /// one's prices.
  Future<void> unsubscribe();

  Future<void> dispose();
}
