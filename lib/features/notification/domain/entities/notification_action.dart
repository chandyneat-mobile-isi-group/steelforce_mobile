import 'package:equatable/equatable.dart';

/// What tapping an inline action button does
/// (`docs/feature/notification/README.md` §12).
enum NotificationActionType {
  /// Navigate to the notification's own `deep_link`.
  ///
  /// Note it is the *notification's* link, not one carried by the action — §11
  /// is explicit that the backend builds these and three clients assembling the
  /// same URI is three chances for one of them to be subtly wrong.
  deeplink('deeplink'),

  /// Call `method endpoint` with the bearer token, then record the action.
  apiCall('api_call'),

  /// Close it — `DELETE /{id}`.
  dismiss('dismiss');

  const NotificationActionType(this.code);

  final String code;

  static NotificationActionType? tryFromCode(String? code) {
    if (code == null || code.isEmpty) return null;
    final normalized = code.toLowerCase();
    for (final value in values) {
      if (value.code == normalized) return value;
    }
    // Deliberately null rather than a default. An action whose type this build
    // cannot execute must be dropped, not guessed at: rendering an
    // "Acknowledge" button that silently does nothing is worse than not
    // offering it, and guessing `api_call` would fire an unknown request.
    return null;
  }
}

/// One inline button on a notification.
///
/// At most three are ever rendered; §12 says to ignore any beyond that, and
/// [NotificationAction.take] enforces it in one place so no screen has to
/// remember.
class NotificationAction extends Equatable {
  const NotificationAction({
    required this.id,
    required this.label,
    required this.type,
    this.endpoint,
    this.method,
    this.destructive = false,
  });

  /// The `actionId` echoed back to `POST /{id}/action`. Sending one the
  /// notification does not offer answers `400 Notification.ActionNotOffered`,
  /// which the error table classifies as a client bug — so this is passed
  /// through verbatim and never synthesised.
  final String id;

  /// Server-localised, already rendered in the rep's language via the
  /// `Accept-Language` header. Safe to show as-is; never run it through `.tr`.
  final String label;

  final NotificationActionType type;

  /// Only meaningful for [NotificationActionType.apiCall].
  final String? endpoint;

  /// `POST`, `PATCH`, … Only meaningful for [NotificationActionType.apiCall].
  final String? method;

  /// Confirm before proceeding. Rejecting a quotation from a lock screen is one
  /// mis-tap from a decision nobody meant to make.
  final bool destructive;

  /// True when this action can actually be executed as described.
  ///
  /// An `api_call` with no endpoint is an unrunnable button. Filtering here
  /// rather than at each call site means the inbox, the sheet and any future
  /// surface all hide the same broken action instead of one of them rendering
  /// it and doing nothing.
  bool get isExecutable => switch (type) {
        NotificationActionType.apiCall =>
          endpoint != null && endpoint!.isNotEmpty,
        NotificationActionType.deeplink => true,
        NotificationActionType.dismiss => true,
      };

  /// The renderable actions from [all], capped at three (§12).
  static List<NotificationAction> take(Iterable<NotificationAction> all) =>
      all.where((a) => a.isExecutable).take(maxButtons).toList(growable: false);

  /// §12: "At most three buttons. Ignore any beyond that."
  static const int maxButtons = 3;

  @override
  List<Object?> get props => [id, label, type, endpoint, method, destructive];
}
