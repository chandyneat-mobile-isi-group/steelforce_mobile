import 'package:steelforce/features/app_coach/domain/entities/coach_action.dart';
import 'package:steelforce/features/app_coach/domain/entities/coach_module.dart';
import 'package:steelforce/features/app_coach/domain/entities/coach_step.dart';
import 'package:steelforce/features/app_coach/presentation/services/coach_keys.dart';

/// The tutorial scripts: the first-run [steps] tour, and the practice
/// lessons in [modules].
///
/// Defined as a `const` Dart list (not a bundled JSON asset) on purpose:
/// zero async, zero parse cost, no pubspec asset wiring, and the analyzer
/// verifies every localization/target id at compile time. Bump [coachVersion]
/// whenever the script changes materially so persisted progress migrates.
abstract final class CoachStepCatalog {
  /// Schema version — increment when steps are added/removed/reordered.
  ///
  /// 11: the practice lessons (depots, quotation, order, visit).
  static const int coachVersion = 11;

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

  /// Every lesson, the tour first. The practice lessons run over demo data
  /// and never block the screen: the rep fills the real forms, so the coach
  /// points and explains while the app stays fully usable.
  static const List<CoachModule> modules = [
    CoachModule(
      id: CoachModuleIds.tour,
      titleKey: 'coach.lessons.tour.title',
      summaryKey: 'coach.lessons.tour.summary',
      steps: steps,
      practice: false,
    ),
    CoachModule(
      id: CoachModuleIds.depots,
      titleKey: 'coach.lessons.depots.title',
      summaryKey: 'coach.lessons.depots.summary',
      steps: _depotSteps,
    ),
    CoachModule(
      id: CoachModuleIds.quotation,
      titleKey: 'coach.lessons.quotation.title',
      summaryKey: 'coach.lessons.quotation.summary',
      steps: _quotationSteps,
    ),
    CoachModule(
      id: CoachModuleIds.order,
      titleKey: 'coach.lessons.order.title',
      summaryKey: 'coach.lessons.order.summary',
      steps: _orderSteps,
    ),
    CoachModule(
      id: CoachModuleIds.visit,
      titleKey: 'coach.lessons.visit.title',
      summaryKey: 'coach.lessons.visit.summary',
      steps: _visitSteps,
    ),
  ];

  /// The module with [id], or null for an unknown (stale persisted) id.
  static CoachModule? moduleById(String? id) {
    for (final m in modules) {
      if (m.id == id) return m;
    }
    return null;
  }

  // ── A · Depots ─────────────────────────────────────────────────────
  static const List<CoachStep> _depotSteps = [
    _Lesson.intro('depots.intro', order: 1),
    _Lesson.act('depots.open', CoachAction.openDepots,
        target: CoachKeys.myDepots, onHome: true, order: 2),
    _Lesson.act('depots.add', CoachAction.startCreateDepot,
        target: CoachKeys.depotAdd, order: 3),
    _Lesson.act('depots.identity', CoachAction.depotFormAddress,
        target: CoachKeys.depotFormNext,
        failure: CoachAction.depotFormInvalid,
        failureKey: 'coach.lesson.depots.form_invalid',
        order: 4),
    _Lesson.act('depots.address', CoachAction.depotFormContact,
        target: CoachKeys.depotFormNext,
        failure: CoachAction.depotFormInvalid,
        failureKey: 'coach.lesson.depots.form_invalid',
        order: 5),
    _Lesson.act('depots.contact', CoachAction.depotFormSalesTerms,
        target: CoachKeys.depotFormNext,
        failure: CoachAction.depotFormInvalid,
        failureKey: 'coach.lesson.depots.form_invalid',
        order: 6),
    _Lesson.act('depots.sales_terms', CoachAction.depotFormDocuments,
        target: CoachKeys.depotFormNext,
        failure: CoachAction.depotFormInvalid,
        failureKey: 'coach.lesson.depots.form_invalid',
        order: 7),
    _Lesson.act('depots.documents', CoachAction.depotFormReview,
        target: CoachKeys.depotFormNext,
        failure: CoachAction.depotFormInvalid,
        failureKey: 'coach.lesson.depots.form_invalid',
        order: 8),
    _Lesson.act('depots.submit', CoachAction.createDepotSucceeded,
        target: CoachKeys.depotFormNext,
        failure: CoachAction.createDepotFailed,
        failureKey: 'coach.lesson.depots.submit_failed',
        order: 9),
    _Lesson.act('depots.find', CoachAction.openDepotDetails,
        target: CoachKeys.depotFirstCard, order: 10),
    // No target: the Edit button it pointed at is hidden.
    _Lesson.info('depots.manage', order: 11),
    _Lesson.done('depots.done', order: 12),
  ];

  // ── B · Quotation without a visit ──────────────────────────────────
  static const List<CoachStep> _quotationSteps = [
    _Lesson.intro('quotation.intro', order: 1),
    _Lesson.act('quotation.open_depots', CoachAction.openDepots,
        target: CoachKeys.myDepots, onHome: true, order: 2),
    _Lesson.act('quotation.start', CoachAction.startCreateQuotation,
        target: CoachKeys.depotFirstCardQuotation, order: 3),
    _Lesson.act('quotation.add_items', CoachAction.quotationItemAdded,
        target: CoachKeys.quotationProducts, order: 4),
    _Lesson.info('quotation.review',
        target: CoachKeys.quotationPreview, order: 5),
    _Lesson.act('quotation.save', CoachAction.createQuotationSucceeded,
        target: CoachKeys.quotationSave,
        failure: CoachAction.createQuotationFailed,
        failureKey: 'coach.lesson.quotation.save_failed',
        order: 6),
    _Lesson.act('quotation.submit', CoachAction.submitQuotationSucceeded,
        target: CoachKeys.quotationSubmit,
        failure: CoachAction.submitQuotationFailed,
        failureKey: 'coach.lesson.quotation.submit_failed',
        order: 7),
    _Lesson.done('quotation.done', order: 8),
  ];

  // ── C · Order without a visit ──────────────────────────────────────
  static const List<CoachStep> _orderSteps = [
    _Lesson.intro('order.intro', order: 1),
    _Lesson.act('order.open', CoachAction.openOrders,
        target: CoachKeys.orders, onHome: true, order: 2),
    _Lesson.act('order.open_quotation', CoachAction.openQuotationDetails,
        target: CoachKeys.ordersFirstRow, order: 3),
    _Lesson.act('order.convert', CoachAction.startCreateOrder,
        target: CoachKeys.quotationConvert, order: 4),
    _Lesson.act('order.create', CoachAction.createOrderSucceeded,
        target: CoachKeys.salesOrderCreate,
        failure: CoachAction.createOrderFailed,
        failureKey: 'coach.lesson.order.create_failed',
        order: 5),
    _Lesson.done('order.done', order: 6),
  ];

  // ── D · Visit ──────────────────────────────────────────────────────
  static const List<CoachStep> _visitSteps = [
    _Lesson.intro('visit.intro', order: 1),
    _Lesson.act('visit.open', CoachAction.openMyVisits,
        target: CoachKeys.myVisits, onHome: true, order: 2),
    _Lesson.act('visit.select', CoachAction.openVisitDetails,
        target: CoachKeys.visitFirstStop, order: 3),
    _Lesson.act('visit.start', CoachAction.startCheckIn,
        target: CoachKeys.visitStart, order: 4),
    _Lesson.act('visit.check_in', CoachAction.checkInSucceeded,
        target: CoachKeys.visitCheckIn,
        failure: CoachAction.checkInFailed,
        failureKey: 'coach.lesson.visit.check_in_failed',
        order: 5),
    _Lesson.act('visit.survey', CoachAction.submitVisitSurveySucceeded,
        target: CoachKeys.visitSurveySubmit,
        failure: CoachAction.submitVisitSurveyFailed,
        failureKey: 'coach.lesson.visit.survey_failed',
        order: 6),
    _Lesson.act('visit.complete', CoachAction.completeVisitSucceeded,
        target: CoachKeys.visitComplete,
        failure: CoachAction.completeVisitFailed,
        failureKey: 'coach.lesson.visit.complete_failed',
        order: 7),
    _Lesson.done('visit.done', order: 8),
  ];
}

/// Lesson steps. Keys follow `coach.lesson.<id>.title` / `.message`, and every
/// lesson step is non-blocking and stays on the screen the rep is on.
class _Lesson extends CoachStep {
  /// The lesson's opening card: what it teaches, and that it is practice.
  const _Lesson.intro(String id, {required super.order})
      : super(
          id: id,
          titleKey: 'coach.lesson.$id.title',
          messageKey: 'coach.lesson.$id.message',
          ctaKey: 'coach.cta.start_lesson',
          requiredAction: CoachAction.none,
          advanceOnCta: true,
          autoNavigateHome: false,
          blocking: false,
        );

  /// Waits for [action] — a real screen opening or a confirmed result.
  const _Lesson.act(
    String id,
    CoachAction action, {
    required String target,
    required super.order,
    bool onHome = false,
    CoachAction? failure,
    String? failureKey,
  }) : super(
          id: id,
          titleKey: 'coach.lesson.$id.title',
          messageKey: 'coach.lesson.$id.message',
          ctaKey: 'coach.cta.skip_step',
          requiredAction: action,
          targetKeyId: target,
          autoNavigateHome: onHome,
          blocking: false,
          failureAction: failure,
          failureMessageKey: failureKey,
        );

  /// Explains what is on screen; "Got it" moves on.
  const _Lesson.info(String id, {String? target, required super.order})
      : super(
          id: id,
          titleKey: 'coach.lesson.$id.title',
          messageKey: 'coach.lesson.$id.message',
          ctaKey: 'coach.cta.got_it',
          requiredAction: CoachAction.none,
          targetKeyId: target,
          advanceOnCta: true,
          autoNavigateHome: false,
          blocking: false,
        );

  /// The completion card.
  const _Lesson.done(String id, {required super.order})
      : super(
          id: id,
          titleKey: 'coach.lesson.$id.title',
          messageKey: 'coach.lesson.$id.message',
          ctaKey: 'coach.cta.finish',
          requiredAction: CoachAction.none,
          advanceOnCta: true,
          autoNavigateHome: false,
          blocking: false,
          canSkip: false,
        );
}
