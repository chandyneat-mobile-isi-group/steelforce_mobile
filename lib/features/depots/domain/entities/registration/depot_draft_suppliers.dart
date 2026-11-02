import 'package:equatable/equatable.dart';

/// Where a ranked supplier comes from: SteelForce's own Branch or Factory
/// list (`GET /api/v1/profile-lists/branch|factory`). The OpenAPI sample shows
/// `1`/`2`; the server binds enums by name, so the name is what is sent.
enum DepotSupplierType {
  branch('Branch', 'branch'),
  factory('Factory', 'factory');

  const DepotSupplierType(this.apiValue, this.listName);

  final String apiValue;

  /// The `{list}` segment of the profile-lists route.
  final String listName;

  static DepotSupplierType? fromApi(Object? value) {
    for (final type in values) {
      if (type.apiValue == '$value') return type;
    }
    return null;
  }
}

class DepotDraftSupplier extends Equatable {
  const DepotDraftSupplier({required this.type, required this.code});

  final DepotSupplierType type;

  /// A code of that list, as the server returned it.
  final String code;

  @override
  List<Object?> get props => [type, code];
}

/// Up to three ranked suppliers, in order with no gap, each only once.
///
/// On create, leaving the whole object out means "none". (On a later edit it
/// would mean "keep what the draft has" — the backend's one exception to full
/// replacement.)
class DepotDraftSuppliers extends Equatable {
  const DepotDraftSuppliers({this.primary, this.secondary, this.tertiary});

  final DepotDraftSupplier? primary;
  final DepotDraftSupplier? secondary;
  final DepotDraftSupplier? tertiary;

  bool get isEmpty => primary == null && secondary == null && tertiary == null;

  /// No gap in the ranking and no supplier twice — the server's own rule.
  bool get isWellFormed {
    if (tertiary != null && secondary == null) return false;
    if (secondary != null && primary == null) return false;
    final ranked =
        [primary, secondary, tertiary].whereType<DepotDraftSupplier>();
    return ranked.toSet().length == ranked.length;
  }

  @override
  List<Object?> get props => [primary, secondary, tertiary];
}
