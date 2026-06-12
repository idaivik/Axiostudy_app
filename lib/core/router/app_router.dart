import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/data/auth_providers.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/test/presentation/test_screen.dart';
import '../../features/results/presentation/results_screen.dart';
import '../../features/subjects/presentation/chapter_detail_screen.dart';
import '../../features/analytics/presentation/analytics_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/profile/presentation/settings_screen.dart';
import '../../features/onboarding/presentation/test_selection_screen.dart';
import '../../features/practice/presentation/practice_screen.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/gradient_background.dart';
import 'swipe_nav_provider.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final isLoggedIn = ref.watch(isLoggedInProvider);

  return GoRouter(
    initialLocation: isLoggedIn ? '/' : '/login',
    redirect: (context, state) {
      final loggingIn = state.matchedLocation == '/login';
      if (!isLoggedIn && !loggingIn) return '/login';
      if (isLoggedIn && loggingIn) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
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
            path: '/profile',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ProfileScreen(),
            ),
          ),
        ],
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
        ),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/test-selection',
        builder: (context, state) => const TestSelectionScreen(),
      ),
    ],
  );
});

/// Shell scaffold with bottom nav, gradient background, and swipe navigation.
class _ShellScaffold extends ConsumerStatefulWidget {
  final Widget child;
  const _ShellScaffold({required this.child});

  @override
  ConsumerState<_ShellScaffold> createState() => _ShellScaffoldState();
}

class _ShellScaffoldState extends ConsumerState<_ShellScaffold> {
  static const _routes = ['/', '/practice', '/analytics', '/profile'];

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
