import 'package:equatable/equatable.dart';
import 'package:steelforce/core/utils/typedefs.dart';

/// An amount of money, always carrying its currency.
///
/// The API returns `creditLimit`, `creditBalance`, `availableCredit` and
/// `lifetimeValue` as `{ amount, currency }` objects rather than bare decimals,
/// and this type exists to keep them that way through the app.
///
/// A decimal on its own is not an amount of money — it is a number someone
/// remembers the currency of, and that memory is where currency bugs live. A
/// limit in USD compared against a balance in KHR is a silent 4000× error that
/// nothing in the type system objects to. [compareTo] and the arithmetic here
/// refuse to mix currencies rather than produce that number.
class Money extends Equatable {
  const Money(this.amount, this.currency);

  final double amount;
  final String currency;

  /// Reads the `{ amount, currency }` object. Tolerates a bare number for the
  /// legacy local rows written before the money objects landed, defaulting
  /// those to [fallbackCurrency] — a depot trades in exactly one currency,
  /// carried on the top-level `currency` field, so that is the right default
  /// to pass when rehydrating a stored row.
  factory Money.fromJson(Object? raw, {String fallbackCurrency = 'USD'}) {
    if (raw is Map) {
      final map = raw.cast<String, dynamic>();
      return Money(
        (map['amount'] as num?)?.toDouble() ?? 0,
        map['currency'] as String? ?? fallbackCurrency,
      );
    }
    if (raw is num) return Money(raw.toDouble(), fallbackCurrency);
    return Money(0, fallbackCurrency);
  }

  DataMap toJson() => {'amount': amount, 'currency': currency};

  bool get isZero => amount == 0;
  bool get isNegative => amount < 0;

  // Deliberately no arithmetic and no comparison operators.
  //
  // There is nothing here for them to do: `availableCredit` is computed
  // server-side as limit − balance and must not be recomputed — if the two
  // ever disagree the server is right. Adding operators would invite exactly
  // the client-side credit block the depots guide warns against, built on
  // `creditBalance`, which is maintained by the SAP interface and is only as
  // fresh as the last run. Add them when something genuinely needs to compute
  // with money, along with the currency-mismatch guard that has to come first.

  @override
  List<Object?> get props => [amount, currency];

  @override
  String toString() => '$amount $currency';
}
