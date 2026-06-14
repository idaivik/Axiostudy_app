import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../supabase/supabase_providers.dart';
import '../../features/auth/data/auth_providers.dart';
import '../../features/auth/domain/user_model.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/onboarding/data/onboarding_providers.dart';
import '../../features/onboarding/presentation/splash_screen.dart';
import '../../features/onboarding/presentation/exam_selection_screen.dart';
import '../../features/onboarding/presentation/profiling_screen.dart';
import '../../features/subscription/presentation/paywall_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/test/presentation/test_screen.dart';
import '../../features/results/presentation/results_screen.dart';
import '../../features/subjects/presentation/chapter_detail_screen.dart';
import '../../features/analytics/presentation/analytics_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/profile/presentation/settings_screen.dart';
import '../../features/onboarding/presentation/test_selection_screen.dart';
import '../../features/practice/presentation/practice_screen.dart';
import '../../features/practice/data/practice_providers.dart';
import '../../features/practice/data/practice_repository.dart';
import '../../features/roadmap/presentation/roadmap_screen.dart';
import '../../features/roadmap/presentation/roadmap_setup_screen.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/gradient_background.dart';
import 'swipe_nav_provider.dart';

/// Auth screens reachable while signed out.
const Set<String> _authRoutes = {'/login', '/signup'};

final routerProvider = Provider<GoRouter>((ref) {
  // Re-run redirect whenever auth state or the loaded profile changes, without
  // rebuilding the whole router (which would reset navigation state).
  final refresh = ValueNotifier<int>(0);
  ref.listen(isLoggedInProvider, (_, _) => refresh.value++);
  ref.listen(currentUserProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  // Check the persisted session synchronously so returning users land on the
  // splash (then their gate) instead of flashing the login screen first.
  final hasSession =
      ref.read(supabaseClientProvider).auth.currentSession != null;
  final initialLoggedIn = ref.read(guestModeProvider) || hasSession;

  return GoRouter(
    initialLocation: initialLoggedIn ? '/splash' : '/login',
    refreshListenable: refresh,
    redirect: (context, state) => _onboardingGuard(ref, state),
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding/exam',
        builder: (context, state) => const ExamSelectionScreen(),
      ),
      GoRoute(
        path: '/paywall',
        builder: (context, state) => const PaywallScreen(),
      ),
      GoRoute(
        path: '/onboarding/profiling',
        builder: (context, state) => const ProfilingScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            _ShellScaffold(child: child),
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HomeScreen(),
            ),
          ),
          GoRoute(
            path: '/practice',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: PracticeScreen(),
            ),
          ),
          GoRoute(
            path: '/analytics',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: AnalyticsScreen(),
            ),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SettingsScreen(),
            ),
          ),
        ],
      ),
      // Profile lives outside the shell and opens as a panel that slides in
      // from the left when the home-screen avatar is tapped.
      GoRoute(
        path: '/profile',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const ProfileScreen(),
          transitionDuration: const Duration(milliseconds: 320),
          reverseTransitionDuration: const Duration(milliseconds: 260),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(-1, 0),
                end: Offset.zero,
              ).animate(curved),
              child: FadeTransition(opacity: curved, child: child),
            );
          },
        ),
      ),
      GoRoute(
        path: '/test/:testId',
        builder: (context, state) => TestScreen(
          testId: state.pathParameters['testId']!,
        ),
      ),
      GoRoute(
        path: '/results/:attemptId',
        builder: (context, state) => ResultsScreen(
          attemptId: state.pathParameters['attemptId']!,
        ),
      ),
      GoRoute(
        path: '/subjects/:subjectId',
        builder: (context, state) => ChapterDetailScreen(
          subjectId: state.pathParameters['subjectId']!,
          focusChapterId: state.uri.queryParameters['chapter'],
        ),
      ),
      GoRoute(
        path: '/test-selection',
        builder: (context, state) => const TestSelectionScreen(),
      ),
      // Adaptive practice runner — picks up the in-memory session prepared by
      // the practice screen (assembled from weak chapters / generation).
      GoRoute(
        path: '/practice/session',
        builder: (context, state) {
          final test = ref.read(activePracticeTestProvider);
          if (test == null) return const PracticeScreen();
          return TestScreen(
            testId: PracticeRepository.adaptiveTestId,
            test: test,
          );
        },
      ),
      // Coaching-synced study roadmap (lives outside the shell).
      GoRoute(
        path: '/roadmap',
        builder: (context, state) => const RoadmapScreen(),
      ),
      GoRoute(
        path: '/roadmap/setup',
        builder: (context, state) => const RoadmapSetupScreen(),
      ),
    ],
  );
});

/// Enforces the signup funnel: signed-out → auth screens; signed-in → the next
/// required onboarding gate (exam → paywall → profiling) until complete.
String? _onboardingGuard(Ref ref, GoRouterState state) {
  final loc = state.matchedLocation;
  final loggedIn = ref.read(isLoggedInProvider);

  // ── Signed out ──────────────────────────────────────────────────────────────
  if (!loggedIn) {
    return _authRoutes.contains(loc) ? null : '/login';
  }

  // ── Guest / test bypass ─────────────────────────────────────────────────────
  if (ref.read(guestModeProvider)) {
    if (_authRoutes.contains(loc) ||
        loc == '/splash' ||
        kOnboardingRoutes.contains(loc)) {
      return '/';
    }
    return null;
  }

  // ── Profile still loading ───────────────────────────────────────────────────
  final userAsync = ref.read(currentUserProvider);
  if (userAsync.isLoading) {
    // Keep user on splash while we wait; don't yank them off a funnel screen.
    if (loc == '/splash' || kOnboardingRoutes.contains(loc)) return null;
    if (_authRoutes.contains(loc)) return '/splash';
    // Already inside the app — let them stay while profile refreshes.
    return null;
  }

  final UserModel? user = userAsync.valueOrNull;
  if (user == null) {
    // Resolved with no profile (fetch error / session race) — send to login
    // so the user can re-authenticate rather than being stuck forever.
    return _authRoutes.contains(loc) ? null : '/login';
  }

  // ── Profile loaded — enforce onboarding funnel ───────────────────────────────
  final step = onboardingStepFor(user);
  if (step != OnboardingStep.done) {
    // Allow the correct funnel screen; redirect to it from everywhere else
    // (including /splash, so the splash is never a dead-end).
    return loc == step.route ? null : step.route;
  }

  // ── Fully onboarded — bounce out of auth/splash/funnel routes ───────────────
  if (_authRoutes.contains(loc) ||
      loc == '/splash' ||
      kOnboardingRoutes.contains(loc)) {
    return '/';
  }
  return null;
}

/// Shell scaffold with bottom nav, gradient background, and swipe navigation.
class _ShellScaffold extends ConsumerStatefulWidget {
  final Widget child;
  const _ShellScaffold({required this.child});

  @override
  ConsumerState<_ShellScaffold> createState() => _ShellScaffoldState();
}

class _ShellScaffoldState extends ConsumerState<_ShellScaffold> {
  static const _routes = ['/', '/practice', '/analytics', '/settings'];

  @override
  Widget build(BuildContext context) {
    final swipeState = ref.watch(swipeNavProvider);

    // Sync index from current location when navigated by means other than
    // the swipe/nav-tap handlers (e.g. deep links, go_router redirects).
    final location = GoRouterState.of(context).matchedLocation;
    final idx = _routes.indexOf(location);
    if (idx >= 0 && idx != swipeState.navIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(swipeNavProvider.notifier).setGlobalIndex(
          SwipeNavState.globalIndexForNav(idx),
        );
      });
    }

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity < -300) {
          _navigateForward();
        } else if (velocity > 300) {
          _navigateBackward();
        }
      },
      child: GradientBackground(
        bottomNavigationBar: BottomNavBar(
          currentIndex: swipeState.navIndex,
          onTap: (index) {
            ref.read(swipeNavProvider.notifier).onNavTap(index);
            context.go(_routes[index]);
          },
        ),
        child: _SlidePageSwitcher(
          routeKey: location,
          isForward: swipeState.isForward,
          child: widget.child,
        ),
      ),
    );
  }

  void _navigateForward() {
    final current = ref.read(swipeNavProvider);
    if (current.globalIndex >= SwipeNavState.totalPages - 1) return;
    ref.read(swipeNavProvider.notifier).swipeLeft();
    final newRoute = _routes[ref.read(swipeNavProvider).navIndex];
    if (newRoute != GoRouterState.of(context).matchedLocation) {
      context.go(newRoute);
    }
  }

  void _navigateBackward() {
    final current = ref.read(swipeNavProvider);
    if (current.globalIndex <= 0) return;
    ref.read(swipeNavProvider.notifier).swipeRight();
    final newRoute = _routes[ref.read(swipeNavProvider).navIndex];
    if (newRoute != GoRouterState.of(context).matchedLocation) {
      context.go(newRoute);
    }
  }
}

/// Slides the incoming page in whenever [routeKey] changes.
/// The new page enters from the right (forward) or left (backward).
/// No previous-child snapshot is kept — avoids Flutter's forgotten-element
/// assertion that fires when a widget is moved between tree positions.
class _SlidePageSwitcher extends StatefulWidget {
  final Widget child;
  final String routeKey;
  final bool isForward;

  const _SlidePageSwitcher({
    required this.child,
    required this.routeKey,
    required this.isForward,
  });

  @override
  State<_SlidePageSwitcher> createState() => _SlidePageSwitcherState();
}

class _SlidePageSwitcherState extends State<_SlidePageSwitcher>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      value: 1.0, // start complete — no animation on first render
    );
    _buildAnim(widget.isForward);
  }

  void _buildAnim(bool isForward) {
    _slideAnim = Tween<Offset>(
      begin: isForward ? const Offset(1.0, 0) : const Offset(-1.0, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void didUpdateWidget(_SlidePageSwitcher old) {
    super.didUpdateWidget(old);
    if (old.routeKey != widget.routeKey) {
      _buildAnim(widget.isForward);
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(position: _slideAnim, child: widget.child);
  }
}
