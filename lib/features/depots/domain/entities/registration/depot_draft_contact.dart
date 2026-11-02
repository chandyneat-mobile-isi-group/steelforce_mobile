import 'package:equatable/equatable.dart';

/// A contact's role. The backend accepts exactly these six (`ContactRole`).
enum DepotContactRole {
  owner('Owner'),
  manager('Manager'),
  accountant('Accountant'),
  purchaser('Purchaser'),
  sales('Sales'),
  other('Other');

  const DepotContactRole(this.apiValue);

  /// The string the server binds — its enum name, not the ordinal.
  final String apiValue;

  /// Null for a value this build does not know, so a newer server role is
  /// shown as unknown rather than throwing.
  static DepotContactRole? fromApi(Object? value) {
    for (final role in values) {
      if (role.apiValue == '$value') return role;
    }
    return null;
  }
}

/// One person at the depot. Needs an English or a Khmer name (or both).
class DepotDraftContact extends Equatable {
  const DepotDraftContact({
    required this.key,
    required this.role,
    this.id,
    this.nameEn,
    this.nameKh,
    this.phoneNumber,
    this.email,
    this.isPrimary = false,
  });

  /// Local, stable row identity for list keys and edits. Never sent.
  final String key;

  /// The server's id, set only on a contact read back from a saved draft.
  /// Null for a new contact — the server mints it.
  final String? id;

  final String? nameEn;
  final String? nameKh;
  final DepotContactRole role;
  final String? phoneNumber;
  final String? email;

  /// At most one per draft; when none is marked the server makes the first
  /// contact primary.
  final bool isPrimary;

  bool get hasName =>
      (nameEn?.trim().isNotEmpty ?? false) ||
      (nameKh?.trim().isNotEmpty ?? false);

  DepotDraftContact copyWith({
    String? nameEn,
    String? nameKh,
    DepotContactRole? role,
    String? phoneNumber,
    String? email,
    bool? isPrimary,
  }) =>
      DepotDraftContact(
        key: key,
        id: id,
        nameEn: nameEn ?? this.nameEn,
        nameKh: nameKh ?? this.nameKh,
        role: role ?? this.role,
        phoneNumber: phoneNumber ?? this.phoneNumber,
        email: email ?? this.email,
        isPrimary: isPrimary ?? this.isPrimary,
      );

  @override
  List<Object?> get props =>
      [key, id, nameEn, nameKh, role, phoneNumber, email, isPrimary];
}
