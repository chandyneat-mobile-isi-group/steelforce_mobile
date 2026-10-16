import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/session/unsent_work.dart';

class _Source implements UnsentWorkSource {
  _Source(this.debugName, this.log, {this.throws = false});

  @override
  final String debugName;
  final List<String> log;
  final bool throws;

  @override
  Future<int> countUnsent() async => 1;
  @override
  Future<int> countSendable() async => 1;
  @override
  Future<void> sendNow() async {
    log.add(debugName);
    if (throws) throw StateError('down');
  }
}

class _Described extends _Source implements UnsentWorkBreakdown {
  _Described(super.debugName, super.log, this.parts);
  final List<UnsentWorkCount> parts;
  @override
  Future<List<UnsentWorkCount>> breakdown() async => parts;
}

void main() {
  const logger = ConsoleAppLogger(verbose: false);
  late List<String> log;
  late UnsentWorkService service;

  setUp(() {
    log = [];
    service = UnsentWorkService([
      _Source('depots', log),
      _Source('check_ins', log, throws: true),
      _Source('orders', log),
      _Source('check_outs', log),
    ], logger);
  });

  test('sendAll sends top to bottom — the order the server receives', () async {
    await service.sendAll();
    expect(log, ['depots', 'check_ins', 'orders', 'check_outs']);
  });

  test('sendBefore sends only what is registered ahead, in order', () async {
    await service.sendBefore('orders');
    expect(log, ['depots', 'check_ins'],
        reason: 'a failing source does not stop the ones after it');
  });

  test('sendBefore the first source, or an unknown one, sends nothing',
      () async {
    await service.sendBefore('depots');
    await service.sendBefore('nope');
    expect(log, isEmpty);
  });

  test('breakdown merges kinds, keeps send order, drops empty kinds', () async {
    final service = UnsentWorkService([
      _Described('quotes', log, const [
        UnsentWorkCount(UnsentWorkKind.quotations, 2, needsAction: 1),
      ]),
      _Described('check_ins', log, const [
        UnsentWorkCount(UnsentWorkKind.adHocVisits, 0),
        UnsentWorkCount(UnsentWorkKind.checkIns, 3),
      ]),
      _Described('depots', log, const [
        UnsentWorkCount(UnsentWorkKind.depotRegistrations, 1),
      ]),
      _Source('legacy', log),
    ], logger);

    final parts = await service.breakdown();

    expect([
      for (final p in parts) (p.kind, p.unsent, p.needsAction)
    ], [
      (UnsentWorkKind.depotRegistrations, 1, 0),
      (UnsentWorkKind.checkIns, 3, 0),
      (UnsentWorkKind.quotations, 2, 1),
      (UnsentWorkKind.other, 1, 0),
    ]);
    expect(log, isEmpty, reason: 'a preview never sends');
  });
}
