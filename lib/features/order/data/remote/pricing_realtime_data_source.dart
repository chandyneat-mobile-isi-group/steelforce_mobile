import 'dart:async';

import 'package:steelforce/features/order/domain/entities/mobile_price.dart';
import 'package:steelforce/features/order/domain/repositories/pricing_repository.dart';

/// The realtime seam, with nothing behind it yet.
///
/// ## Why this is a stub and not a SignalR client
///
/// The hub contract is specified — connect to `/hubs/pricing` with the access
/// token on the query string, call `SubscribeToPricingAsync(depotId)`,
/// listen for `PricingUpdated` — but **no SignalR client is in `pubspec.yaml`**
/// and adding a package is not a decision to make silently.
///
/// The alternative was hand-rolling the SignalR handshake and negotiate
/// protocol over a raw socket. That is a re-implementation of a wire protocol
/// nobody asked for, it would be the second authentication mechanism the spec
/// explicitly forbids, and it would have to be thrown away the moment the real
/// client is added.
///
/// So this satisfies the interface and connects to nothing. Every price is
/// therefore REST-fetched and marked live-until-proven-otherwise, which is
/// exactly the behaviour a rep gets today. Nothing above this class knows the
/// difference, and swapping in the real transport is one registration change.
///
/// TODO(release-gate): replace with a `signalr_netcore` implementation once the
/// dependency is approved. The replacement owes the caller three things this
/// stub documents but cannot provide:
///
///  1. `PricingUpdated` events mapped through `MobilePriceMapper.fromUpdateEvent`
///     and pushed to [updates], one per material.
///  2. A [reconnections] event on every successful reconnect — group
///     membership does not survive a dropped connection, so the caller must
///     re-fetch over REST *and* re-subscribe. The hub does not replay.
///  3. [isConnected] tracking the transport honestly, so the UI can mark
///     prices stale rather than showing a dead figure as live.
class DisconnectedPricingRealtimeSource implements PricingRealtimeSource {
  DisconnectedPricingRealtimeSource();

  final _updates = StreamController<MobilePrice>.broadcast();
  final _reconnections = StreamController<void>.broadcast();

  @override
  Stream<MobilePrice> get updates => _updates.stream;

  @override
  Stream<void> get reconnections => _reconnections.stream;

  /// Always false, and honestly so: there is no transport. The UI reads this
  /// to decide whether to show a "live" indicator, and claiming a connection
  /// that does not exist would put a live badge over a figure nothing is
  /// keeping current.
  @override
  bool get isConnected => false;

  @override
  Future<void> subscribe(String depotId) async {}

  @override
  Future<void> unsubscribe() async {}

  @override
  Future<void> dispose() async {
    await _updates.close();
    await _reconnections.close();
  }
}
