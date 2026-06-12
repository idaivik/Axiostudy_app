import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../features/auth/data/auth_providers.dart';
import '../../../features/onboarding/presentation/diagnostic_modal.dart';
import '../../analytics/data/analytics_providers.dart';
import 'widgets/diagnostic_prompt_card.dart';
import 'widgets/notifications_sheet.dart';
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
  static const _kDiagnosticModalShown = 'diagnostic_modal_shown';
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

  Future<void> _checkDiagnostic() async {
    final hasTaken = ref.read(hasTakenDiagnosticProvider);
    if (hasTaken) return;

    final prefs = await SharedPreferences.getInstance();
    final alreadyShown = prefs.getBool(_kDiagnosticModalShown) ?? false;
    if (alreadyShown) return;

    await prefs.setBool(_kDiagnosticModalShown, true);
    if (mounted) showDiagnosticModal(context);
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.valueOrNull;
    final firstName = user?.name.split(' ').first ?? 'Student';

    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          // Invalidate all home-relevant providers to force full re-fetch
          ref.invalidate(currentUserProvider);
          ref.invalidate(topicPerformanceProvider);
          ref.invalidate(weakTopicsProvider);
          ref.invalidate(scoreHistoryProvider);
          ref.invalidate(studyStreakProvider);

          // Wait for user data to reload so the UI refreshes visibly
          await ref.read(currentUserProvider.future);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
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
                        // Profile avatar (circle, left)
                        GestureDetector(
                          onTap: () => context.go('/profile'),
                          child: Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              gradient: AppColors.heroGradient,
                              shape: BoxShape.circle,
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
                        const SizedBox(width: 14),
                        // Greeting text
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hello $firstName,',
                                style: AppTypography.heading1.copyWith(
                                  fontSize: 22,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _greeting(),
                                style: AppTypography.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w400,
                                  color: AppColors.textLight,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Notification bell (right)
                        GestureDetector(
                          onTap: () => showNotificationsSheet(context),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceLight,
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                child: Center(
                                  child: Icon(
                                    LucideIcons.bell,
                                    size: 22,
                                    color: AppColors.textMedium,
                                  ),
                                ),
                              ),
                              // Red badge dot when diagnostic is pending
                              if (!ref.watch(hasTakenDiagnosticProvider))
                                Positioned(
                                  top: -2,
                                  right: -2,
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: AppColors.wrong,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.cardBackground,
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
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
                  const DiagnosticPromptCard(),
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
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

class _AIInsightStrip extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weakAsync = ref.watch(weakTopicsProvider);
    final weakTopics = weakAsync.valueOrNull ?? [];

    final message = weakTopics.isEmpty
        ? 'Take a test to get your personalized AI study insights'
        : weakTopics.length == 1
            ? 'AI detected 1 weak topic from your tests — focus on ${_topicName(weakTopics.first.topicId)} today'
            : 'AI detected ${weakTopics.length} weak topics from your tests — focus on those today';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.greenWash,
        borderRadius: BorderRadius.circular(14),
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
              message,
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

  String _topicName(String topicId) {
    final parts = topicId.split('_');
    if (parts.length >= 3) {
      return parts.sublist(2).map((s) {
        if (s.isEmpty) return s;
        return s[0].toUpperCase() + s.substring(1);
      }).join(' ');
    }
    return topicId;
  }
}

