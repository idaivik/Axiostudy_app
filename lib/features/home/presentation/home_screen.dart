import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../features/auth/data/auth_providers.dart';
import 'widgets/score_trends_card.dart';
import 'widgets/study_streak_card.dart';
import 'widgets/daily_goal_card.dart';
import 'widgets/upcoming_tests_card.dart';
import 'widgets/areas_to_improve_card.dart';
import '../../../features/onboarding/presentation/diagnostic_modal.dart';

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
    final user = ref.watch(currentUserProvider);

    return SafeArea(
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hi, ${user?.name.split(' ').first ?? 'Student'} 👋',
                          style: AppTypography.heading1,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Let\'s crush your goals today!',
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

          // Dashboard cards
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 8),
                const DailyGoalCard(),
                const ScoreTrendsCard(),
                const StudyStreakCard(),
                const UpcomingTestsCard(),
                const AreasToImproveCard(),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
