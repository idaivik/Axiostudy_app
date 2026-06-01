import 'package:flutter/material.dart';

/// AxioStudy brand color palette.
///
/// Design philosophy: Friendly, not intimidating. Soft colors,
/// encouraging tone. Pink theme feels approachable and unique
/// compared to corporate blue competitors.
class AppColors {
  AppColors._();

  // ─── Background Gradient ───
  static const Color backgroundGradientStart = Color(0xFFFFE5F0);
  static const Color backgroundGradientEnd = Color(0xFFFFF0F5);

  // ─── Primary (Hot Pink) ───
  static const Color primary = Color(0xFFFF69B4);
  static const Color primaryLight = Color(0xFFFF8DC7);
  static const Color primaryDark = Color(0xFFE91E8C);
  static const Color primarySurface = Color(0xFFFFF0F7);

  // ─── Secondary ───
  static const Color secondary = Color(0xFF6C5CE7);
  static const Color secondaryLight = Color(0xFFA29BFE);

  // ─── Semantic Colors ───
  static const Color success = Color(0xFF70B77E);
  static const Color successLight = Color(0xFFE8F5E9);
  static const Color warning = Color(0xFFFF8C42);
  static const Color warningLight = Color(0xFFFFF3E0);
  static const Color error = Color(0xFFE74C3C);
  static const Color errorLight = Color(0xFFFFEBEE);

  // ─── Text ───
  static const Color textDark = Color(0xFF1C1C1E);
  static const Color textMedium = Color(0xFF48484A);
  static const Color textLight = Color(0xFF8E8E93);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // ─── Surfaces ───
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color surfaceLight = Color(0xFFFFF5F9);
  static const Color surfaceDark = Color(0xFFF2F2F7);
  static const Color divider = Color(0xFFE5E5EA);

  // ─── Subject-Specific ───
  static const Color physics = Color(0xFF5B86E5);
  static const Color chemistry = Color(0xFF36D1DC);
  static const Color mathematics = Color(0xFFFF6B6B);

  // ─── Gradients ───
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [backgroundGradientStart, backgroundGradientEnd],
  );

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryLight, primary],
  );

  static const LinearGradient physicsGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF5B86E5), Color(0xFF36D1DC)],
  );

  static const LinearGradient chemistryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF36D1DC), Color(0xFF5B86E5)],
  );

  static const LinearGradient mathematicsGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
  );
}
