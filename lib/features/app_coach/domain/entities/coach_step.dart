import 'package:equatable/equatable.dart';
import 'package:steelforce/features/app_coach/domain/entities/coach_action.dart';

/// A single tutorial step.
///
/// This is a pure domain object — it deliberately holds a [targetKeyId]
/// (a plain string) rather than a Flutter `GlobalKey`, so the domain layer
/// stays framework-free. The presentation layer resolves the id to a live
/// `GlobalKey` through `CoachKeys`, and the overlay tolerates a missing/unmounted
/// target by falling back to a centered bubble (see error-handling rules).
///
/// [titleKey] / [messageKey] / [ctaKey] are localization keys resolved with
/// `.tr`, so the coach speaks the app's active language.
class CoachStep extends Equatable {
  const CoachStep({
    required this.id,
    required this.titleKey,
    required this.messageKey,
    required this.ctaKey,
    required this.requiredAction,
    required this.order,
    this.route = '/main',
    this.targetKeyId,
    this.advanceOnCta = false,
    this.autoNavigateHome = true,
    this.canSkip = true,
    this.blocking = true,
    this.failureAction,
    this.failureMessageKey,
  });

  /// Stable identifier, also used as the persisted "completed step" token.
  final String id;

  final String titleKey;
  final String messageKey;
  final String ctaKey;

  /// Route the step lives on (informational only — navigation is driven by the
  /// shell, not by the coach forcing routes).
  final String route;

  /// Id of the widget to spotlight, or null for a centered, target-less bubble.
  final String? targetKeyId;

  /// The action that advances this step. [CoachAction.none] for informational
  /// steps that advance via their CTA instead.
  final CoachAction requiredAction;

  /// When true the CTA button advances directly (informational steps). When
  /// false the step waits for [requiredAction] and the CTA only offers "skip".
  final bool advanceOnCta;

  /// When true the coach ensures the Home tab is active before showing the step
  /// (all anchors live on Home). Keeps spotlights valid after a tab excursion.
  final bool autoNavigateHome;

  /// Whether the whole tutorial can be skipped from this step.
  final bool canSkip;

  /// True: the classic tour look — dimmed screen, taps allowed only through
  /// the spotlight. False: a guide that never blocks — the rep is filling a
  /// real form, answering dialogs and scrolling, so the coach only points.
  final bool blocking;

  /// The action that means this step's operation came back with an error.
  /// It never advances; it shows [failureMessageKey] so the rep can retry.
  final CoachAction? failureAction;

  /// Retry guidance shown after [failureAction].
  final String? failureMessageKey;

  /// 1-based display order.
  final int order;

  /// Informational steps have no awaited UI action.
  bool get isInformational => requiredAction == CoachAction.none;

  @override
  List<Object?> get props => [id, order, requiredAction, targetKeyId];
}
