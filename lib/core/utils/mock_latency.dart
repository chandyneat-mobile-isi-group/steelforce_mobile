import 'package:steelforce/core/config/data_source_mode.dart';

/// Simulated backend latency for the mock data layer.
///
/// The app currently runs entirely on mock/local data sources; this is the
/// single place that mimics a real (slow) API so loading, skeleton and
/// streaming states are actually exercised end-to-end.
///
/// One knob: change [value] (or set it to [Duration.zero]) to speed the whole
/// app back up. Applied only to *read* paths (catalog/list/credit lookups),
/// never to local mutations like cart edits, so interactions stay snappy.
class MockLatency {
  MockLatency._();

  /// How long a simulated "network" read takes.
  ///
  /// Zero unless the app runs against mocks (`USE_MOCK_DATA=true`): some
  /// real Drift-backed local sources still call [tick], and a live build must
  /// not add a fake 900 ms to every catalogue, quotation and order read.
  static const Duration value =
      DataSourceMode.useMocks ? Duration(milliseconds: 900) : Duration.zero;

  /// Await this at the start of a mock read to simulate the round-trip.
  static Future<void> tick() => value == Duration.zero
      ? Future<void>.value()
      : Future<void>.delayed(value);
}
