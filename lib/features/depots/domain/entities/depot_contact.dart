import 'package:equatable/equatable.dart';

/// A secondary contact (buyer, storekeeper, accountant) reps add themselves.
/// The primary legal contact lives on [Depot] itself and is SAP-owned.
class DepotContact extends Equatable {
  const DepotContact({
    required this.id,
    required this.name,
    required this.role,
    required this.phone,
    this.email,
  });

  final String id;
  final String name;
  final String role;
  final String phone;
  final String? email;

  @override
  List<Object?> get props => [id, name, role, phone, email];
}
