import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'user_role.dart';

part 'user.g.dart';

@JsonSerializable()
class User extends Equatable {
  const User({
    required this.id,
    required this.email,
    required this.fullName,
    required this.roles,
    this.company,
    this.avatarUrl,
  });

  final String id;
  final Set<UserRole> roles;
  final String email;
  final String fullName;
  final String? company;
  final String? avatarUrl;

  // ── Helper Getters & Methods for SessionManager ──

  /// Gets the first assigned role, or defaults to guest if empty.
  UserRole get primaryRole => roles.isNotEmpty ? roles.first : UserRole.guest;

  /// Checks if the user has a specific role.
  bool hasRole(UserRole role) => roles.contains(role);

  /// Checks if the user has at least one role from a collection.
  bool hasAnyRole(Iterable<UserRole> anyRoles) => anyRoles.any(roles.contains);

  /// Checks if the user holds every single role listed.
  bool hasAllRoles(Iterable<UserRole> allRoles) =>
      allRoles.every(roles.contains);

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  Map<String, dynamic> toJson() => _$UserToJson(this);

  @override
  List<Object?> get props => [id, email, fullName, roles, company, avatarUrl];
}
