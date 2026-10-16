import 'package:equatable/equatable.dart';
import 'package:steelforce/core/utils/name_initials.dart';

/// The signed-in employee as `GET /auth/me` describes them — everything the
/// profile screen shows.
///
/// **Permissions and feature flags are deliberately absent.** They are the
/// session's business (`SessionManager`), not something an employee reads
/// about themselves, and a list of grant strings on a profile screen is noise.
class WorkerProfile extends Equatable {
  const WorkerProfile({
    required this.id,
    required this.fullName,
    required this.employeeCode,
    required this.email,
    required this.phone,
    this.position,
    this.department,
    this.roleLabel,
    this.territoryCode,
    this.depotCode,
    this.language,
    this.timeZone,
    this.avatarUrl,
    this.lastLoginAt,
    this.passwordExpiresAt,
    this.isActive = true,
    this.khmerName,
    this.lineManagerName,
    this.lineManagerCode,
    this.temporaryPasswordExpiresAt,
    this.avatarThumbnailUrl,
  });

  final String id;
  final String fullName;
  final String employeeCode;
  final String email;
  final String phone;

  /// The HR job title — `position` on the wire, `jobTitle` when written.
  final String? position;

  final String? department;

  /// The coarse role bucket, for when HR recorded no [position].
  final String? roleLabel;

  final String? territoryCode;

  /// Null for a rep not attached to a depot — the common case.
  final String? depotCode;

  /// BCP 47, e.g. `km-KH`.
  final String? language;

  /// IANA, e.g. `Asia/Phnom_Penh`.
  final String? timeZone;

  /// An **absolute** address, ready for an image widget. Null when the
  /// employee has never set a picture — every account, until somebody does.
  final String? avatarUrl;

  /// The small square version of [avatarUrl], for the round avatar. Absolute,
  /// like [avatarUrl]. The full-size [avatarUrl] is for the full-screen view.
  final String? avatarThumbnailUrl;

  final DateTime? lastLoginAt;
  final DateTime? passwordExpiresAt;
  final bool isActive;

  /// The name in Khmer script, when HR holds one.
  final String? khmerName;

  /// Who the rep reports to, and that manager's employee code.
  final String? lineManagerName;
  final String? lineManagerCode;

  /// When the temporary password stops working. Set only while one is in
  /// force.
  final DateTime? temporaryPasswordExpiresAt;

  /// What the profile shows for the line manager: the **name only** — the
  /// manager's employee code is not shown. Null when no name was sent.
  String? get lineManager => lineManagerName;

  /// What the header chip shows: the job title, else the role.
  String get title => position ?? roleLabel ?? '';

  String get initials => nameInitials(fullName) ?? '?';

  @override
  List<Object?> get props => [
        id,
        fullName,
        employeeCode,
        email,
        phone,
        position,
        department,
        roleLabel,
        territoryCode,
        depotCode,
        language,
        timeZone,
        avatarUrl,
        lastLoginAt,
        passwordExpiresAt,
        isActive,
        khmerName,
        lineManagerName,
        lineManagerCode,
        temporaryPasswordExpiresAt,
        avatarThumbnailUrl,
      ];
}
