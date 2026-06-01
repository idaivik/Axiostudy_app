import 'package:flutter/material.dart';

/// AxioStudy brand color palette.
///
/// Design philosophy: Smart Coach — premium, warm, confident.
/// Deep rose conveys energy and warmth without being childish.
/// A sophisticated crimson-rose that feels premium and serious.
class AppColors {
  AppColors._();

  // ─── Background Gradient ───
  static const Color backgroundGradientStart = Color(0xFFFFF5F7);
  static const Color backgroundGradientEnd = Color(0xFFFFF0F3);

  // ─── Primary (Deep Rose — premium, not hot pink) ───
  static const Color primary = Color(0xFFE11D48);
  static const Color primaryLight = Color(0xFFFB7185);
  static const Color primaryDark = Color(0xFFBE123C);
  static const Color primarySurface = Color(0xFFFFF1F2);

  // ─── Secondary (Warm Amber) ───
  static const Color secondary = Color(0xFFF59E0B);
  static const Color secondaryLight = Color(0xFFFDE68A);

  // ─── Semantic Colors (Positive framing) ───
  static const Color success = Color(0xFF10B981);       // Mastered
  static const Color successLight = Color(0xFFD1FAE5);
  static const Color warning = Color(0xFFF59E0B);       // In Progress
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color info = Color(0xFF60A5FA);           // Needs Practice (not red!)
  static const Color infoLight = Color(0xFFDBEAFE);
  static const Color error = Color(0xFFEF4444);          // Only for destructive actions
  static const Color errorLight = Color(0xFFFEE2E2);

  // ─── Text ───
  static const Color textDark = Color(0xFF1C1917);       // Warm dark
  static const Color textMedium = Color(0xFF57534E);     // Stone 600
  static const Color textLight = Color(0xFFA8A29E);      // Stone 400
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // ─── Surfaces ───
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color surfaceLight = Color(0xFFFAFAF9);   // Stone 50
  static const Color surfaceDark = Color(0xFFF5F5F4);    // Stone 100
  static const Color divider = Color(0xFFE7E5E4);        // Stone 200

  // ─── Subject-Specific ───
  static const Color physics = Color(0xFF6366F1);        // Indigo
  static const Color chemistry = Color(0xFF14B8A6);      // Teal
  static const Color mathematics = Color(0xFFF59E0B);    // Amber

  // ─── Gradients ───
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [backgroundGradientStart, backgroundGradientEnd],
  );

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFB7185), Color(0xFFE11D48)],
  );

  static const LinearGradient physicsGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF818CF8), Color(0xFF6366F1)],
  );

  static const LinearGradient chemistryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2DD4BF), Color(0xFF14B8A6)],
  );

  static const LinearGradient mathematicsGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
  );
}
