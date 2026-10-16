import 'package:steelforce/features/app_coach/domain/entities/coach_action.dart';
import 'package:steelforce/features/app_coach/domain/entities/coach_step.dart';
import 'package:steelforce/features/app_coach/presentation/services/coach_keys.dart';

/// The tutorial script.
///
/// Defined as a `const` Dart list (not a bundled JSON asset) on purpose:
/// zero async, zero parse cost, no pubspec asset wiring, and the analyzer
/// verifies every localization/target id at compile time. Bump [coachVersion]
/// whenever the script changes materially so persisted progress migrates.
abstract final class CoachStepCatalog {
  /// Schema version — increment when steps are added/removed/reordered.
  static const int coachVersion = 10;

  static const List<CoachStep> steps = [
    CoachStep(
      id: 'welcome',
      titleKey: 'coach.welcome.title',
      messageKey: 'coach.welcome.message',
      ctaKey: 'coach.cta.start',
      requiredAction: CoachAction.none,
      advanceOnCta: true,
      order: 1,
    ),
    CoachStep(
      id: 'home_overview',
      titleKey: 'coach.home.title',
      messageKey: 'coach.home.message',
      ctaKey: 'coach.cta.next',
      requiredAction: CoachAction.none,
      advanceOnCta: true,
      order: 2,
    ),
    CoachStep(
      id: 'monthly_target',
      titleKey: 'coach.target.title',
      messageKey: 'coach.target.message',
      ctaKey: 'coach.cta.next',
      requiredAction: CoachAction.none,
      advanceOnCta: true,
      targetKeyId: CoachKeys.monthlyTarget,
      order: 3,
    ),
    CoachStep(
      id: 'my_work',
      titleKey: 'coach.my_work.title',
      messageKey: 'coach.my_work.message',
      ctaKey: 'coach.cta.next',
      requiredAction: CoachAction.none,
      advanceOnCta: true,
      targetKeyId: CoachKeys.myWork,
      order: 4,
    ),
    CoachStep(
      id: 'my_visits',
      titleKey: 'coach.my_visits.title',
      messageKey: 'coach.my_visits.message',
      ctaKey: 'coach.cta.skip_step',
      requiredAction: CoachAction.openMyVisits,
      targetKeyId: CoachKeys.myVisits,
      order: 5,
    ),
    CoachStep(
      id: 'my_depots',
      titleKey: 'coach.depots.title',
      messageKey: 'coach.depots.message',
      ctaKey: 'coach.cta.skip_step',
      requiredAction: CoachAction.openDepots,
      targetKeyId: CoachKeys.myDepots,
      order: 6,
    ),
    CoachStep(
      id: 'orders',
      titleKey: 'coach.orders.title',
      messageKey: 'coach.orders.message',
      ctaKey: 'coach.cta.skip_step',
      requiredAction: CoachAction.openOrders,
      targetKeyId: CoachKeys.orders,
      order: 7,
    ),
    CoachStep(
      id: 'notification',
      titleKey: 'coach.notification.title',
      messageKey: 'coach.notification.message',
      ctaKey: 'coach.cta.next',
      requiredAction: CoachAction.none,
      advanceOnCta: true,
      targetKeyId: CoachKeys.notification,
      order: 8,
    ),
    CoachStep(
      id: 'profile',
      titleKey: 'coach.profile.title',
      messageKey: 'coach.profile.message',
      ctaKey: 'coach.cta.next',
      requiredAction: CoachAction.none,
      advanceOnCta: true,
      targetKeyId: CoachKeys.profile,
      order: 9,
    ),
    CoachStep(
      id: 'completed',
      titleKey: 'coach.done.title',
      messageKey: 'coach.done.message',
      ctaKey: 'coach.cta.finish',
      requiredAction: CoachAction.none,
      advanceOnCta: true,
      canSkip: false,
      order: 10,
    ),
  ];
}
