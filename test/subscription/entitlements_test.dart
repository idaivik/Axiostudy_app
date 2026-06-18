import 'package:flutter_test/flutter_test.dart';
import 'package:axiostudy_app/features/auth/domain/user_model.dart';
import 'package:axiostudy_app/features/subscription/domain/entitlements.dart';
import 'package:axiostudy_app/shared/models/enums.dart';

/// Per-tier `can()` parity with BILLING_PRICING_AND_TIERS_PLAN.md §4, plus the
/// lapse gate and the Pro→Basic downgrade rule (§10). The expected feature sets
/// are hard-coded from §4 (NOT re-derived from kTierCapabilities) so this test
/// catches drift in the capability map itself, not just in `can()`.

UserModel _user({
  required SubscriptionTier tier,
  SubscriptionStatus status = SubscriptionStatus.active,
  DateTime? expiry,
}) =>
    UserModel(
      id: 'u1',
      email: 'u1@example.com',
      name: 'Test',
      subscriptionTier: tier,
      subscriptionStatus: status,
      subscriptionExpiry: expiry,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  // §4 floor — included on BOTH paid tiers.
  const floor = {
    Feature.diagnosticTest,
    Feature.adaptivePractice,
    Feature.progressAnalytics,
    Feature.personalizedPractice,
    Feature.community,
  };

  // §4 Basic = floor + the four basic-flavored rows.
  const basicExpected = {
    ...floor,
    Feature.basicRoadmap,
    Feature.revisionReminders,
    Feature.limitedAiTestGen,
    Feature.basicQuestionBreakdown,
  };

  // §4 Pro = floor + every pro-only row (incl. the P2 ones it sells now).
  const proExpected = {
    ...floor,
    Feature.aiQuestionGeneration,
    Feature.fullAiPractice,
    Feature.aiAnalysisNarrative,
    Feature.aiRoadmap,
    Feature.advancedBreakdown,
    Feature.aiTimeTips,
    Feature.prioritySupport,
    Feature.advancedRevisionPlan,
    Feature.aiNotes,
    Feature.aiFormulaSheet,
  };

  void expectExactly(UserModel u, Set<Feature> allowed) {
    for (final f in Feature.values) {
      expect(u.can(f), allowed.contains(f),
          reason: 'can(${f.name}) should be ${allowed.contains(f)} for $u');
    }
  }

  group('can() per tier (active)', () {
    test('free sentinel grants nothing — even with an active status', () {
      // `free` is the "no entitlement" sentinel: empty capability set.
      expectExactly(_user(tier: SubscriptionTier.free), const {});
    });

    test('Basic unlocks exactly its §4 set', () {
      expectExactly(_user(tier: SubscriptionTier.basic), basicExpected);
    });

    test('Pro unlocks exactly its §4 set', () {
      expectExactly(_user(tier: SubscriptionTier.pro), proExpected);
    });

    test('Basic is locked out of every Pro-only feature', () {
      final u = _user(tier: SubscriptionTier.basic);
      for (final f in proExpected.difference(basicExpected)) {
        expect(u.can(f), isFalse, reason: '${f.name} is Pro-only');
      }
    });
  });

  group('lapse gate (hasActiveAccess ANDs in)', () {
    test('a lapsed (status:none) Pro can() nothing', () {
      final u = _user(tier: SubscriptionTier.pro, status: SubscriptionStatus.none);
      expectExactly(u, const {});
    });

    test('cancelled-but-still-paid keeps access until expiry', () {
      final live = _user(
        tier: SubscriptionTier.pro,
        status: SubscriptionStatus.cancelled,
        expiry: DateTime.now().add(const Duration(days: 5)),
      );
      expect(live.can(Feature.aiQuestionGeneration), isTrue);

      final lapsed = _user(
        tier: SubscriptionTier.pro,
        status: SubscriptionStatus.cancelled,
        expiry: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(lapsed.can(Feature.aiQuestionGeneration), isFalse);
    });

    test('trialing user still has tier access (the AI lock is server-side)', () {
      // The 7-day-trial AI hard-lock is enforced by the edge fn (402
      // trial_ai_locked), NOT by can() — so can() stays true here.
      final u = _user(tier: SubscriptionTier.pro, status: SubscriptionStatus.trialing);
      expect(u.can(Feature.aiQuestionGeneration), isTrue);
    });
  });

  group('Pro→Basic downgrade (§10)', () {
    test('downgrade drops Pro-only capabilities but keeps the floor', () {
      final pro = _user(tier: SubscriptionTier.pro);
      final downgraded = pro.copyWith(subscriptionTier: SubscriptionTier.basic);

      // Pro-only generation/coaching is gone…
      expect(downgraded.can(Feature.aiQuestionGeneration), isFalse);
      expect(downgraded.can(Feature.fullAiPractice), isFalse);
      expect(downgraded.can(Feature.aiRoadmap), isFalse);
      // …but the floor (and Basic's own set) remain — artifacts aren't deleted,
      // they go read-only, so basic access is intact.
      expectExactly(downgraded, basicExpected);
    });
  });
}
