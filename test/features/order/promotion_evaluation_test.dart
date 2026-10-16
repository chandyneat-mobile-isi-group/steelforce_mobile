import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/localization/localized_text.dart';
import 'package:steelforce/features/order/data/repositories/static_promotion_repository_impl.dart';
import 'package:steelforce/features/order/domain/entities/promotion/promotion.dart';
import 'package:steelforce/features/order/domain/entities/promotion/promotion_evaluation.dart';
import 'package:steelforce/features/order/domain/entities/promotion/promotion_tier.dart';

/// The ladder from the design: 300 → 15, 500 → 35, 2000 → 280.
Promotion _ladder({
  Set<String> depotIds = const {},
  Set<String> categoryCodes = const {'FG-RF'},
  DateTime? from,
  DateTime? until,
}) =>
    Promotion(
      id: 'p1',
      title: const LocalizedText(en: 'Camstar Free Goods', km: ''),
      unitLabel: 'Bag',
      categoryCodes: categoryCodes,
      depotIds: depotIds,
      validFrom: from ?? DateTime(2026, 1, 1),
      validUntil: until ?? DateTime(2026, 12, 31),
      tiers: const [
        PromotionTier(minQuantity: 300, freeQuantity: 15),
        PromotionTier(minQuantity: 500, freeQuantity: 35),
        PromotionTier(minQuantity: 2000, freeQuantity: 280),
      ],
    );

PromotionEvaluation _evaluate(Promotion promotion, int quantity) =>
    PromotionEvaluation(
      promotion: promotion,
      quantity: quantity,
      earnedTier: promotion.tierFor(quantity),
      nextTier: promotion.nextTierFor(quantity),
    );

void main() {
  group('which rung a quantity has earned', () {
    test('below the first rung earns nothing', () {
      final result = _evaluate(_ladder(), 280);
      expect(result.isEligible, isFalse);
      expect(result.freeQuantity, 0);
    });

    test('exactly on a rung earns it', () {
      final result = _evaluate(_ladder(), 300);
      expect(result.isEligible, isTrue);
      expect(result.freeQuantity, 15);
    });

    test('between rungs earns the lower one, never a pro-rata', () {
      // Rounding a depot's entitlement is a commercial decision and not the
      // handset's to make: 400 bags earns the 300 benefit, not 25.
      final result = _evaluate(_ladder(), 400);
      expect(result.freeQuantity, 15);
    });

    test('above the top rung stays on the top rung', () {
      final result = _evaluate(_ladder(), 5000);
      expect(result.freeQuantity, 280);
      expect(result.nextTier, isNull);
      expect(result.quantityToNextTier, isNull);
    });
  });

  group('the prompt towards the next rung', () {
    test('names the gap and the reward', () {
      // "Buy 20 more bags to get 15 free" — the sentence a rep says out loud.
      final result = _evaluate(_ladder(), 280);
      expect(result.quantityToNextTier, 20);
      expect(result.nextTier?.freeQuantity, 15);
    });

    test('keeps prompting once a rung is earned', () {
      final result = _evaluate(_ladder(), 300);
      expect(result.freeQuantity, 15);
      expect(result.quantityToNextTier, 200);
      expect(result.nextTier?.freeQuantity, 35);
    });

    test('progress is measured from the earned rung, not from zero', () {
      // 400 of the way from 300 to 500 is halfway, not 80%.
      final result = _evaluate(_ladder(), 400);
      expect(result.progressToNextTier, closeTo(0.5, 0.001));
    });
  });

  group('depot scope', () {
    test('an unscoped promotion reaches everyone, including a walk-in', () {
      expect(_ladder().appliesToDepot('cust_1'), isTrue);
      expect(_ladder().appliesToDepot(null), isTrue);
    });

    test('a named-account deal never leaks to another depot', () {
      final deal = _ladder(depotIds: {'cust_1'});
      expect(deal.appliesToDepot('cust_1'), isTrue);
      expect(deal.appliesToDepot('cust_2'), isFalse);
    });

    test('a named-account deal never leaks to a walk-in', () {
      // A null depot must match only unscoped promotions — showing a
      // negotiated deal to an unidentified buyer is a leak, not a convenience.
      expect(_ladder(depotIds: {'cust_1'}).appliesToDepot(null), isFalse);
    });
  });

  group('lifecycle', () {
    final now = DateTime(2026, 6, 15);

    test('running today is active', () {
      expect(_ladder().lifecycleAt(now), PromotionLifecycle.active);
    });

    test('not started yet is upcoming', () {
      final future =
          _ladder(from: DateTime(2026, 8, 1), until: DateTime(2026, 9, 30));
      expect(future.lifecycleAt(now), PromotionLifecycle.upcoming);
    });

    test('finished is expired', () {
      final past =
          _ladder(from: DateTime(2026, 1, 1), until: DateTime(2026, 3, 31));
      expect(past.lifecycleAt(now), PromotionLifecycle.expired);
    });
  });

  group('the repository', () {
    DateTime clock() => DateTime(2026, 6, 15);
    final repo = StaticPromotionRepositoryImpl(clock: clock);

    test('never returns an expired promotion', () async {
      final result = await repo.getPromotions();
      final promotions = result.when(
          success: (p) => p, failure: (f) => throw StateError(f.message));
      for (final promotion in promotions) {
        expect(
            promotion.lifecycleAt(clock()), isNot(PromotionLifecycle.expired));
      }
    });

    test('omits upcoming promotions unless asked for them', () async {
      final without = (await repo.getPromotions())
          .when(success: (p) => p, failure: (_) => <Promotion>[]);
      final with_ = (await repo.getPromotions(includeUpcoming: true))
          .when(success: (p) => p, failure: (_) => <Promotion>[]);
      expect(with_.length, greaterThan(without.length));
    });

    test('an upcoming promotion never evaluates against a line', () async {
      // It is worth showing on the dashboard and never worth applying: a rep
      // must not quote free goods that do not exist yet.
      final result = await repo.evaluate(
        materialCode: 'M1',
        categoryCode: 'FG-PIPE',
        quantity: 100000,
      );
      expect(result.when(success: (e) => e, failure: (_) => null), isNull);
    });

    test('a material no promotion covers evaluates to null', () async {
      // Null renders as nothing — an empty strip on every unpromoted product
      // would be permanent noise.
      final result = await repo.evaluate(
        materialCode: 'M1',
        categoryCode: 'NOT-A-CATEGORY',
        quantity: 500,
      );
      expect(result.when(success: (e) => e, failure: (_) => null), isNull);
    });

    test('a covered material evaluates against its ladder', () async {
      final result = await repo.evaluate(
        materialCode: 'M1',
        categoryCode: 'FG-RF',
        quantity: 500,
      );
      final evaluation = result.when(success: (e) => e, failure: (_) => null);
      expect(evaluation, isNotNull);
      expect(evaluation!.isEligible, isTrue);
      expect(evaluation.freeQuantity, 35);
    });
  });
}
