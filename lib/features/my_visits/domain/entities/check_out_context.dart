import 'package:equatable/equatable.dart';
import 'package:steelforce/features/my_visits/domain/entities/check_out_outcome.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_stop.dart';

/// What the check-out sheet needs: the stop being visited and the orders
/// already taken there.
class CheckOutContext extends Equatable {
  const CheckOutContext({required this.stop, this.orders = const []});

  final RouteStop stop;

  /// Quotations saved for this shop since the rep checked in, newest first.
  final List<VisitOrderOption> orders;

  @override
  List<Object?> get props => [stop, orders];
}

/// One order the rep can say the visit produced.
class VisitOrderOption extends Equatable {
  const VisitOrderOption({
    required this.ref,
    required this.createdAt,
    required this.itemCount,
    required this.total,
  });

  final VisitOrderRef ref;
  final DateTime createdAt;
  final int itemCount;
  final double total;

  @override
  List<Object?> get props => [ref, createdAt, itemCount, total];
}
