import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../features/auth/data/auth_providers.dart';
import '../../../features/onboarding/presentation/diagnostic_modal.dart';
import 'widgets/readiness_banner.dart';
import 'widgets/todays_plan_card.dart';
import 'widgets/strength_meter_card.dart';
import 'widgets/score_trends_card.dart';
import 'widgets/upcoming_tests_card.dart';

/// Home screen — the "Smart Coach" dashboard.
///
/// Information hierarchy:
/// 1. Greeting + Readiness score
/// 2. Today's Plan (primary CTA)
/// 3. Strength Meter (subject progress)
/// 4. Recent Performance (score trends)
/// 5. Next Test (single upcoming test)
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _hasShownDiagnosticModal = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkDiagnosticPrompt();
    });
  }

  void _checkDiagnosticPrompt() {
    final hasTaken = ref.read(hasTakenDiagnosticProvider);
    if (!hasTaken && !_hasShownDiagnosticModal) {
      _hasShownDiagnosticModal = true;
      showDiagnosticModal(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.valueOrNull;

    return SafeArea(
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Header — clean, professional greeting
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hi, ${user?.name.split(' ').first ?? 'Student'}',
                          style: AppTypography.heading1,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Here\'s your study plan for today',
                          style: AppTypography.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.go('/profile'),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          user?.name.substring(0, 1) ?? 'S',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Dashboard cards — strict priority order
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 8),
                const ReadinessBanner(),
                const TodaysPlanCard(),
                const StrengthMeterCard(),
                const ScoreTrendsCard(),
                const UpcomingTestCard(),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
