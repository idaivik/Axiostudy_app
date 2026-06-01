import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../features/auth/data/auth_providers.dart';
import '../../../features/onboarding/presentation/diagnostic_modal.dart';
import 'widgets/readiness_banner.dart';
import 'widgets/todays_plan_card.dart';
import 'widgets/strength_meter_card.dart';
import 'widgets/score_trends_card.dart';
import 'widgets/upcoming_tests_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  bool _hasShownDiagnosticModal = false;
  late AnimationController _headerController;
  late Animation<double> _headerFade;
  late Animation<Offset> _headerSlide;

  @override
  void initState() {
    super.initState();
    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _headerFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _headerController, curve: Curves.easeOut),
    );
    _headerSlide = Tween<Offset>(begin: const Offset(0, -0.12), end: Offset.zero).animate(
      CurvedAnimation(parent: _headerController, curve: Curves.easeOutCubic),
    );
    _headerController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) => _checkDiagnostic());
  }

  @override
  void dispose() {
    _headerController.dispose();
    super.dispose();
  }

  void _checkDiagnostic() {
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
    final firstName = user?.name.split(' ').first ?? 'Student';

    return SafeArea(
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _headerFade,
              child: SlideTransition(
                position: _headerSlide,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _greeting(firstName),
                              style: AppTypography.heading1,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              "Here's your AI study plan for today",
                              style: AppTypography.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () => context.go('/profile'),
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            gradient: AppColors.heroGradient,
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.25),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              (user?.name.isNotEmpty == true)
                                  ? user!.name[0].toUpperCase()
                                  : 'S',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 19,
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
            ),
          ),

          // AI insight strip
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _headerFade,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: _AIInsightStrip(),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const ReadinessBanner(),
                const TodaysPlanCard(),
                const StrengthMeterCard(),
                const ScoreTrendsCard(),
                const UpcomingTestCard(),
                const SizedBox(height: 110),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  String _greeting(String name) {
    final h = DateTime.now().hour;
    final g = h < 12 ? 'Good morning' : h < 17 ? 'Good afternoon' : 'Good evening';
    return '$g, $name';
  }
}

class _AIInsightStrip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.greenWash,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.greenSurface, width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(LucideIcons.brain, size: 14, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'AI detected 2 weak topics from your last test — focus on those today',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.greenStrong,
                height: 1.4,
              ),
            ),
          ),
          Icon(LucideIcons.chevronRight, size: 14, color: AppColors.primary),
        ],
      ),
    );
  }
}
