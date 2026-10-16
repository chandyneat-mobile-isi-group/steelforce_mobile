import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/session/session_scoped_store.dart';

class _RecordingStore implements SessionScopedStore {
  _RecordingStore(this.debugName, {this.throws = false});

  @override
  final String debugName;
  final bool throws;
  bool cleared = false;

  @override
  Future<void> clearForSignOut() async {
    cleared = true;
    if (throws) throw StateError('boom');
  }
}

void main() {
  const logger = ConsoleAppLogger(verbose: false);

  test('every registered store is cleared', () async {
    final a = _RecordingStore('a');
    final b = _RecordingStore('b');

    await SessionResetService([a, b], logger).clearAll();

    expect(a.cleared, isTrue);
    expect(b.cleared, isTrue);
  });

  test('one failing store never strands the others', () async {
    // A cart that refuses to clear must not leave an active visit session
    // behind for the next rep to inherit, and must not stop the sign-out.
    final failing = _RecordingStore('cart', throws: true);
    final after = _RecordingStore('workflow');

    await expectLater(
      SessionResetService([failing, after], logger).clearAll(),
      completes,
    );

    expect(after.cleared, isTrue,
        reason: 'a store after the failure must still be cleared');
  });

  test('clearing with nothing registered is a no-op', () async {
    await expectLater(
      SessionResetService(const [], logger).clearAll(),
      completes,
    );
  });
}
