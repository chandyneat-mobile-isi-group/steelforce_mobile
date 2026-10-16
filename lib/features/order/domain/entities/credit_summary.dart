import 'package:equatable/equatable.dart';
import 'package:steelforce/features/order/domain/entities/credit_note_debit_note.dart';

/// Mocked SAP credit position for one depot. `creditRemaining` is
/// deliberately not stored here — callers compute it as
/// `depot.creditLimit - outstandingBalance`, since `creditLimit` already
/// lives on `Depot` and shouldn't be duplicated.
class CreditSummary extends Equatable {
  const CreditSummary({required this.outstandingBalance, required this.notes});

  final double outstandingBalance;
  final List<CreditNoteDebitNote> notes;

  bool get hasOpenNotes => notes.any((n) => !n.settled);

  @override
  List<Object?> get props => [outstandingBalance, notes];
}
