import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Manages the global swipe-navigation page index across all sections.
///
/// The virtual page order (0-6):
///   0 → Home
///   1 → Practice (Topics tab)
///   2 → Practice (Mock Tests tab)
///   3 → Analytics (Overview tab)
///   4 → Analytics (Topics tab)
///   5 → Analytics (Trends tab)
///   6 → Profile
///
/// This maps to 4 bottom-nav sections with sub-tab offsets.
class SwipeNavState {
  final int globalIndex;
  /// true = navigating forward (left swipe / higher index); false = backward.
  final bool isForward;

  const SwipeNavState({this.globalIndex = 0, this.isForward = true});

  static const int totalPages = 7;

  // Section start indices — used to determine cross-section jumps.
  static const List<int> _sectionStarts = [0, 1, 3, 6];

  /// Returns the bottom-nav index (0-3) for the current global page.
  int get navIndex {
    if (globalIndex == 0) return 0;
    if (globalIndex <= 2) return 1;
    if (globalIndex <= 5) return 2;
    return 3;
  }

  /// Returns the sub-tab index within Practice (0-1).
  int get practiceTabIndex => (globalIndex - 1).clamp(0, 1);

  /// Returns the sub-tab index within Analytics (0-2).
  int get analyticsTabIndex => (globalIndex - 3).clamp(0, 2);

  /// Computes the global index from a bottom-nav tap.
  /// Always lands at the first sub-tab of the section.
  static int globalIndexForNav(int navIndex) {
    switch (navIndex) {
      case 0: return 0;
      case 1: return 1;
      case 2: return 3;
      case 3: return 6;
      default: return 0;
    }
  }

  SwipeNavState copyWith({int? globalIndex, bool? isForward}) => SwipeNavState(
        globalIndex: globalIndex ?? this.globalIndex,
        isForward: isForward ?? this.isForward,
      );
}

class SwipeNavNotifier extends StateNotifier<SwipeNavState> {
  SwipeNavNotifier() : super(const SwipeNavState());

  void setGlobalIndex(int index) {
    state = state.copyWith(globalIndex: index.clamp(0, SwipeNavState.totalPages - 1));
  }

  void swipeLeft() {
    if (state.globalIndex >= SwipeNavState.totalPages - 1) return;
    state = state.copyWith(globalIndex: state.globalIndex + 1, isForward: true);
  }

  void swipeRight() {
    if (state.globalIndex <= 0) return;
    // When at a section boundary, jump to the start of the previous section
    // so backward swipes always land at a section's first tab, not the last.
    int newIndex;
    if (SwipeNavState._sectionStarts.contains(state.globalIndex)) {
      final prev = SwipeNavState._sectionStarts
          .lastWhere((s) => s < state.globalIndex);
      newIndex = prev;
    } else {
      newIndex = state.globalIndex - 1;
    }
    state = state.copyWith(globalIndex: newIndex, isForward: false);
  }

  void onNavTap(int navIndex) {
    final newIndex = SwipeNavState.globalIndexForNav(navIndex);
    final forward = navIndex >= state.navIndex;
    state = state.copyWith(globalIndex: newIndex, isForward: forward);
  }
}

final swipeNavProvider = StateNotifierProvider<SwipeNavNotifier, SwipeNavState>((ref) {
  return SwipeNavNotifier();
});
