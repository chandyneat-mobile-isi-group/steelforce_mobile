import 'package:equatable/equatable.dart';
import 'package:steelforce/features/authentication/domain/entities/user.dart';
import 'package:steelforce/features/authentication/domain/entities/user_role.dart';

/// The signed-in employee, as returned by `GET /auth/me`.
///
/// This is deliberately richer than [User] and deliberately separate from it.
/// The `id_token` returned at sign-in is an OIDC identity token that the app
/// does not need: it does not carry [territoryCode], [depotCode] or
/// [featureFlags], and those decide what the rep actually sees. Read the
/// profile from `/auth/me` instead.
class AuthProfile extends Equatable {
  const AuthProfile({
    required this.id,
    required this.employeeId,
    required this.email,
    required this.fullName,
    this.roles = const {},
    this.permissions = const {},
    this.featureFlags = const {},
    this.territoryCode,
    this.depotCode,
    this.language,
    this.timeZone,
    this.theme,
    this.passwordExpiresAt,
    this.company,
    this.avatarUrl,
    this.phoneNumber,
    this.position,
    this.department,
    this.lastLoginAt,
    this.passwordChangeRequired = false,
    this.khmerName,
    this.temporaryPasswordExpiresAt,
    this.lineManagerName,
    this.lineManagerCode,
    this.avatarThumbnailUrl,
  });

  final String id;

  /// The personnel number on the rep's badge and payslip. Field staff sign in
  /// with this; portal users sign in with [email]. The server resolves
  /// whichever arrives, so the login form needs one field.
  final String employeeId;

  final String email;
  final String fullName;
  final Set<UserRole> roles;

  /// Fine-grained grants, e.g. `depots.create`, `depots.readall`.
  ///
  /// **Client-side permission checks are a courtesy, never a security
  /// control.** The server re-checks every one. Use these to hide a button a
  /// user cannot press, not to protect anything.
  final Set<String> permissions;

  /// Absent flags mean off, so a client built against a newer server degrades
  /// quietly instead of throwing.
  final Map<String, bool> featureFlags;

  final String? territoryCode;
  final String? depotCode;

  /// The user's own language preference. Prefer this over the device locale on
  /// first launch — a rep whose handset is in English may well work in Khmer.
  final String? language;

  final String? timeZone;
  final String? theme;

  /// When set and near, route the user to the change-password screen before
  /// they are locked out mid-shift.
  final DateTime? passwordExpiresAt;

  final String? company;
  final String? avatarUrl;

  /// Contact number as held by HR. The profile screen shows it; nothing
  /// branches on it, and it is never used to identify the account.
  final String? phoneNumber;

  /// Job title, e.g. "Sales Representative". Distinct from [roles]: [position]
  /// is what HR calls the job and is display-only, whereas a [UserRole] is a
  /// coarse authorisation bucket. They usually read the same but are not the
  /// same thing, and the server can change one without the other.
  final String? position;

  final String? department;

  /// Previous successful sign-in. Useful on the profile screen as a passive
  /// "was this you?" signal.
  final DateTime? lastLoginAt;

  /// Signed in with a temporary password: the rep must choose their own
  /// before reaching the shell. Cached with the profile so killing the app
  /// on the change-password screen does not skip the step on the next launch.
  final bool passwordChangeRequired;

  /// The name in Khmer script, when HR holds one. [fullName] is the English
  /// name.
  final String? khmerName;

  /// When the temporary password stops working. Only set while
  /// [passwordChangeRequired] is true.
  final DateTime? temporaryPasswordExpiresAt;

  /// Who the rep reports to — `lineManager.englishName` / `.empCode`.
  final String? lineManagerName;
  final String? lineManagerCode;

  /// The square, small version of [avatarUrl] — `profilePhotoThumbnailUrl`.
  /// Both are signed and stop working at the server's `urlExpiresAt`; the next
  /// profile read hands out fresh ones.
  final String? avatarThumbnailUrl;

  /// The best available human-readable job label, preferring what HR calls the
  /// job over the coarse authorisation bucket.
  String? get positionOrRoleLabel {
    if (position != null && position!.trim().isNotEmpty) return position;
    if (roles.isEmpty) return null;
    return roles.first.name;
  }

  bool can(String permission) => permissions.contains(permission);

  bool canAny(Iterable<String> any) => any.any(permissions.contains);

  /// Convenience for the depot capabilities, which span two namespaces.
  bool get canReadDepots => canAny(Permissions.canReadDepots);
  bool get canCreateDepots => canAny(Permissions.canCreateDepots);
  bool get canUpdateDepots => canAny(Permissions.canUpdateDepots);

  /// Reads a feature flag, treating an absent flag as off.
  bool flag(String name) => featureFlags[name] ?? false;

  /// Row-level scope: a plain rep sees only their own depots, a holder of
  /// `depots.readall` sees the whole territory. Enforced server-side in the
  /// query handler; this only decides whether to offer the "all depots"
  /// filter in the UI.
  bool get canSeeAllDepots => can(Permissions.depotsReadAll);

  /// True once [passwordExpiresAt] is within [window].
  bool passwordExpiringWithin(Duration window) {
    final expiry = passwordExpiresAt;
    if (expiry == null) return false;
    return expiry.difference(DateTime.now().toUtc()) <= window;
  }

  /// The narrower shape the existing session plumbing consumes.
  User toUser() => User(
        id: id,
        email: email,
        fullName: fullName,
        roles: roles,
        company: company,
        avatarUrl: avatarUrl,
      );

  @override
  List<Object?> get props => [
        id,
        employeeId,
        email,
        fullName,
        roles,
        permissions,
        featureFlags,
        territoryCode,
        depotCode,
        passwordChangeRequired,
      ];
}

/// The permission strings the app actually branches on. Kept together so a
/// typo is a compile error rather than a silently hidden button.
abstract final class Permissions {
  static const depotsRead = 'depots.read';
  static const depotsCreate = 'depots.create';
  static const depotsUpdate = 'depots.update';

  // ── The `outlets.*` namespace ──────────────────────────────────────
  //
  // The running backend grants sales representatives `outlets.read`,
  // `outlets.create` and `outlets.update` — the same capability under a
  // different name. There is no `/mobile/outlets` route (it 404s), so these
  // are the depot permissions, not a separate feature.
  //
  // Both spellings are therefore accepted wherever a depot capability is
  // required. Checking only the `depots.*` spelling hid the directory from
  // every rep whose role uses the other one, which is the whole population.
  static const outletsRead = 'outlets.read';
  static const outletsCreate = 'outlets.create';
  static const outletsUpdate = 'outlets.update';

  /// Any of these means "may read the depot directory".
  static const canReadDepots = {depotsRead, outletsRead};

  /// Any of these means "may register a depot". The created record lands in
  /// `Draft` regardless — activating it needs [depotsApprove], which reps
  /// deliberately do not hold.
  static const canCreateDepots = {depotsCreate, outletsCreate};

  /// Any of these means "may edit a depot".
  static const canUpdateDepots = {depotsUpdate, outletsUpdate};

  /// **Sales representatives do not hold this.** A rep pressing Delete gets a
  /// 403. Hide the action rather than letting them discover that.
  static const depotsDelete = 'depots.delete';

  /// Widens row-level scope from "assigned to me" to the whole territory.
  static const depotsReadAll = 'depots.readall';

  /// Gates `createdBy` / `updatedBy` on the depot detail payload — everyone
  /// else receives null, so do not render an empty "Last edited by" row.
  static const depotsAudit = 'depots.audit';

  /// Moves a depot out of `Draft` so it can trade.
  static const depotsApprove = 'depots.approve';
}
