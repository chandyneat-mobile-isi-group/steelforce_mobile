import 'dart:math';

import 'package:steelforce/core/utils/mock_latency.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/domain/entities/credit_note_debit_note.dart';
import 'package:steelforce/features/order/domain/entities/credit_summary.dart';
import 'package:steelforce/features/order/domain/services/credit_service.dart';

const _creditNoteReasons = [
  'Return — damaged goods',
  'Price adjustment',
  'Promotional credit'
];
const _debitNoteReasons = [
  'Freight surcharge',
  'Late payment fee',
  'Short shipment correction'
];

/// Stand-in for an online SAP credit-position lookup — deterministic per
/// depot (seeded off `depotId.hashCode`) so the same shop shows the
/// same mocked figures every time, with a short simulated network delay.
class MockCreditService implements CreditService {
  const MockCreditService();

  @override
  ResultFuture<CreditSummary> getSummary(String depotId) async {
    await MockLatency.tick(); // simulate a slow SAP credit lookup
    final rand = Random(depotId.hashCode);
    final outstandingBalance = (rand.nextDouble() * 4000).roundToDouble();
    final noteCount = rand.nextInt(4); // 0-3
    final notes = <CreditNoteDebitNote>[
      for (var i = 0; i < noteCount; i++)
        _buildNote(rand, depotId: depotId, index: i),
    ];
    return Success(
        CreditSummary(outstandingBalance: outstandingBalance, notes: notes));
  }

  CreditNoteDebitNote _buildNote(Random rand,
      {required String depotId, required int index}) {
    final type = rand.nextBool()
        ? CreditDebitNoteType.creditNote
        : CreditDebitNoteType.debitNote;
    final reasons = type == CreditDebitNoteType.creditNote
        ? _creditNoteReasons
        : _debitNoteReasons;
    final prefix = type == CreditDebitNoteType.creditNote ? 'CN' : 'DN';
    return CreditNoteDebitNote(
      id: '$depotId-note-$index',
      depotId: depotId,
      type: type,
      amount: (50 + rand.nextInt(950)).toDouble(),
      reference: '$prefix-${2000 + rand.nextInt(9000)}',
      reason: reasons[rand.nextInt(reasons.length)],
      issuedDate: DateTime.now().subtract(Duration(days: rand.nextInt(60))),
      settled: rand.nextBool(),
    );
  }
}
