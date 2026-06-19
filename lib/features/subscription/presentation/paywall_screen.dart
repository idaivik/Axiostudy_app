import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/axio_button.dart';
import '../../../shared/models/enums.dart';
import '../../auth/data/auth_providers.dart';
import '../domain/payment_models.dart';
import 'subscription_review_screen.dart';

/// Hard paywall — the plan-selection step. Every new account picks a tier here
/// (each card carries its own "Get Started"), which routes to the
/// [SubscriptionReviewScreen] where the account/plan details are confirmed and
/// the actual store purchase runs. No payment happens on this screen.
///
/// Also reused as an in-app **upgrade** surface ([upgrade] = true): preselect
/// [initialTier] (centred in the carousel), show a close affordance, and on
/// success pop with `true` instead of running the new-account onboarding
/// routing. Push it with [showUpgrade].
class PaywallScreen extends ConsumerStatefulWidget {
  final bool upgrade;
  final SubscriptionTier? initialTier;

  const PaywallScreen({super.key, this.upgrade = false, this.initialTier});

  /// Open the paywall as a dismissible upgrade sheet, preselecting [tier].
  /// Resolves to `true` when the user successfully changed/started a plan.
  static Future<bool?> showUpgrade(
    BuildContext context, {
    SubscriptionTier tier = SubscriptionTier.pro,
  }) {
    return Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PaywallScreen(upgrade: true, initialTier: tier),
      ),
    );
  }

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  BillingPeriod _period = BillingPeriod.annual; // annual pre-selected (hero)

  /// Drives the pricing-card carousel. [_page] tracks the live scroll offset so
  /// each card can scale toward 1.0 as it snaps to centre.
  late final PageController _cardController;
  double _page = 0;

  /// Carousel order — Basic first so opening on Basic leaves Pro peeking past
  /// the right edge (the "you can scroll" hint). An explicit [initialTier]
  /// (upgrade flow) centres that tier instead.
  static const _cards = TrialPlan.all;

  int get _initialIndex {
    final t = widget.initialTier;
    if (t == null) return 0;
    final i = _cards.indexWhere((p) => p.tier == t);
    return i < 0 ? 0 : i;
  }

  @override
  void initState() {
    super.initState();
    _page = _initialIndex.toDouble();
    _cardController = PageController(
      viewportFraction: 0.85, // ~85vw cards, neighbour peeks at the edge
      initialPage: _initialIndex,
    );
    _cardController.addListener(_onCardScroll);
  }

  void _onCardScroll() {
    final p = _cardController.page;
    if (p != null && mounted) setState(() => _page = p);
  }

  @override
  void dispose() {
    _cardController.removeListener(_onCardScroll);
    _cardController.dispose();
    super.dispose();
  }

  /// Each card's "Get Started" carries its tier + the current period to the
  /// review screen, which shows the account + plan details and runs the actual
  /// store purchase. In onboarding the review screen navigates onward itself on
  /// success; in upgrade mode it returns `true`, so we close this sheet (and
  /// refresh the entitlement) too.
  Future<void> _start(SubscriptionTier tier) async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SubscriptionReviewScreen(
          tier: tier,
          period: _period,
          upgrade: widget.upgrade,
        ),
      ),
    );
    if (ok == true && widget.upgrade && mounted) {
      ref.invalidate(currentUserProvider);
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final onboarded =
        ref.watch(currentUserProvider).valueOrNull?.onboardingCompleted ?? false;
    return PopScope(
      // Onboarding: the back gesture walks the funnel back to exam selection.
      // Upgrade sheet: a normal pop just closes it.
      canPop: widget.upgrade,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // New-account funnel only — a lapsed user on the re-paywall (already
        // onboarded) stays put; they can't go back to change their exam.
        if (!widget.upgrade && !onboarded) context.go('/onboarding/exam');
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header: title + period toggle ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.upgrade)
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => Navigator.of(context).maybePop(),
                            icon:
                                Icon(LucideIcons.x, color: AppColors.textLight),
                          ),
                        ),
                      SizedBox(height: widget.upgrade ? 12 : 28),
                      Text('Subscription Plan', style: AppTypography.heading1),
                      const SizedBox(height: 6),
                      Text(
                        'Pick the plan that fits how you study.',
                        style: AppTypography.bodyMedium,
                      ),
                      const SizedBox(height: 22),
                      _PeriodToggle(
                        period: _period,
                        onChanged: (p) => setState(() => _period = p),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                // ── Self-contained pricing cards (snap-to-centre carousel) ──
                _buildCarousel(),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 16),
                  child: Text(
                    'Plans renew automatically until cancelled — cancel anytime. '
                    'By continuing you agree to our Terms & Privacy Policy.',
                    textAlign: TextAlign.center,
                    style: AppTypography.caption.copyWith(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCarousel() {
    return SizedBox(
      height: 500,
      child: PageView.builder(
        controller: _cardController,
        clipBehavior: Clip.none, // let the peeking card bleed to the edge
        itemCount: _cards.length,
        itemBuilder: (context, i) {
          final plan = _cards[i];
          // 1.0 when snapped to centre, easing to 0.0 a page away.
          final centredness = (1 - (_page - i).abs()).clamp(0.0, 1.0);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            child: Transform.scale(
              scale: 0.95 + 0.05 * centredness,
              child: _PlanCard(
                plan: plan,
                period: _period,
                centredness: centredness,
                onStart: () => _start(plan.tier),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A fully self-contained plan card: tier name → price → CTA → feature list,
/// all inside one rounded container with generous padding. The border + shadow
/// lerp with [centredness] so the snapped card reads as focused.
class _PlanCard extends StatelessWidget {
  final TrialPlan plan;
  final BillingPeriod period;
  final double centredness;
  final VoidCallback onStart;

  const _PlanCard({
    required this.plan,
    required this.period,
    required this.centredness,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final annual = period == BillingPeriod.annual;
    final borderColor =
        Color.lerp(AppColors.divider, AppColors.primary, centredness)!;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: borderColor, width: 1 + centredness),
        boxShadow: [
          BoxShadow(
            color: AppColors.slate900.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Reserve a fixed top slot so both cards' names line up (only Pro
          // shows the badge).
          SizedBox(
            height: 24,
            child: plan.isPopular
                ? Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      'MOST POPULAR',
                      style: AppTypography.labelSmall
                          .copyWith(color: Colors.white, fontSize: 10),
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 14),
          // ── Tier name ──
          Text(plan.name, style: AppTypography.heading2),
          const SizedBox(height: 10),
          // ── Price ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(plan.priceLabel(period), style: AppTypography.numberMedium),
              const SizedBox(width: 3),
              Text(
                annual ? '/year' : '/month',
                style: AppTypography.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: 20),
          // ── Call to action ──
          // Pro gets the readiness-banner treatment (green→navy gradient with
          // faint light circles); Basic is a solid-green filled button.
          plan.isPopular
              ? _ProCtaButton(onPressed: onStart)
              : AxioButton(
                  label: 'Get Started',
                  width: double.infinity,
                  onPressed: onStart,
                ),
          const SizedBox(height: 22),
          // ── Feature list (specific to this plan, inside the card) ──
          Text("WHAT'S INCLUDED", style: AppTypography.labelSmall),
          const SizedBox(height: 12),
          for (final f in plan.features) ...[
            _FeatureRow(text: f),
            if (f != plan.features.last) const SizedBox(height: 11),
          ],
          const Spacer(),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final String text;
  const _FeatureRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(LucideIcons.check, size: 16, color: AppColors.primary),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: AppTypography.caption
                .copyWith(color: AppColors.textMedium, height: 1.4),
          ),
        ),
      ],
    );
  }
}

/// Pro plan's CTA — the same green→navy gradient + faint decorative circles as
/// the home "JEE Readiness Score" banner ([AppColors.heroGradient]), sized to a
/// full-width button. Carries the same tap-scale + haptic feel as [AxioButton].
class _ProCtaButton extends StatefulWidget {
  final VoidCallback onPressed;
  const _ProCtaButton({required this.onPressed});

  @override
  State<_ProCtaButton> createState() => _ProCtaButtonState();
}

class _ProCtaButtonState extends State<_ProCtaButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.lightImpact();
        _scaleController.forward();
      },
      onTapUp: (_) {
        _scaleController.reverse();
        widget.onPressed();
      },
      onTapCancel: () => _scaleController.reverse(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: AppColors.heroGradient,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppColors.greenDarkAccent.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Faint light circles — same treatment as the readiness banner,
              // scaled to the button.
              Positioned(
                right: -22,
                top: -30,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
              ),
              Positioned(
                right: 28,
                bottom: -20,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.greenLight.withValues(alpha: 0.12),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('Get Started', style: AppTypography.button),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Monthly / Annual segmented toggle. The tab labels stay perfectly centred —
/// the "1 month extra" value badge is lifted out of flow (a [Positioned] in a
/// non-clipping [Stack]) so it floats over the Annual tab without shifting the
/// text. A pill slides between tabs (labels cross-fade) when the period changes.
/// Entitlements never inspect the period; it only changes the price and store
/// package.
class _PeriodToggle extends StatelessWidget {
  final BillingPeriod period;
  final ValueChanged<BillingPeriod>? onChanged;

  const _PeriodToggle({
    required this.period,
    required this.onChanged,
  });

  static const _slide = Duration(milliseconds: 260);

  @override
  Widget build(BuildContext context) {
    final isAnnual = period == BillingPeriod.annual;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 52,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(100),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final tabWidth = constraints.maxWidth / 2;
              return Stack(
                children: [
                  // Sliding selection pill.
                  AnimatedAlign(
                    duration: _slide,
                    curve: Curves.easeOutCubic,
                    alignment: isAnnual
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      width: tabWidth,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(100),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Perfectly centred labels.
                  Row(
                    children: [
                      _tab(BillingPeriod.monthly, 'Monthly',
                          selected: !isAnnual),
                      _tab(BillingPeriod.annual, 'Annual', selected: isAnnual),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
        // ── Out-of-flow value badge over the Annual tab ──
        Positioned(
          top: -9,
          right: 18,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.greenStrong,
                borderRadius: BorderRadius.circular(7),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.slate900.withValues(alpha: 0.18),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                '1 MONTH EXTRA',
                style: AppTypography.labelSmall
                    .copyWith(color: Colors.white, fontSize: 9),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _tab(BillingPeriod value, String label, {required bool selected}) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onChanged == null ? null : () => onChanged!(value),
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: _slide,
            style: AppTypography.button.copyWith(
              color: selected ? Colors.white : AppColors.textMedium,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}
