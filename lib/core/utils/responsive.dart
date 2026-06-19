import 'package:flutter/widgets.dart';

/// Layout helpers for adapting the UI to bigger screens (tablets) and to
/// landscape orientation. Phones in portrait are the "compact" baseline that
/// the rest of the app is already designed around.
class Responsive {
  Responsive._();

  /// Conventional Material breakpoint — a device whose *shortest* side is at
  /// least this many logical pixels is treated as a tablet, regardless of how
  /// it's currently rotated.
  static const double tabletBreakpoint = 600;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.shortestSide >= tabletBreakpoint;

  static bool isLandscape(BuildContext context) =>
      MediaQuery.of(context).orientation == Orientation.landscape;

  /// True when there's enough horizontal room to lay things out side by side —
  /// a tablet (either orientation) or a phone turned to landscape.
  static bool isWide(BuildContext context) =>
      isTablet(context) || isLandscape(context);

  /// How many columns the subjects grid should use for the given content
  /// [width]. Single column keeps the original phone-portrait layout.
  static int subjectColumns(double width) {
    if (width >= 760) return 3;
    if (width >= 480) return 2;
    return 1;
  }
}
