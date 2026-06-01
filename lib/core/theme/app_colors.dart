import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ─── Base Palette ───
  static const Color white = Color(0xFFFFFFFF);
  static const Color slate900 = Color(0xFF0F172A);

  // ─── Green Scale ───
  static const Color greenDarkAccent = Color(0xFF004225);
  static const Color greenStrong = Color(0xFF166534);
  static const Color primary = Color(0xFF16A34A);       // Primary action
  static const Color greenLight = Color(0xFF4ADE80);    // Light accent
  static const Color greenSurface = Color(0xFFDCFCE7);  // Surface tint
  static const Color greenWash = Color(0xFFF0FDF4);     // Background wash

  // ─── Semantic ───
  static const Color wrong = Color(0xFFDC2626);
  static const Color weak = Color(0xFFEA580C);
  static const Color correct = Color(0xFF16A34A);
  static const Color inactive = Color(0xFFF1F5F9);

  // ─── Text ───
  static const Color textDark = Color(0xFF0F172A);      // Slate 900
  static const Color textMedium = Color(0xFF475569);    // Slate 600
  static const Color textLight = Color(0xFF94A3B8);     // Slate 400
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textOnDark = Color(0xFFFFFFFF);

  // ─── Surfaces ───
  static const Color background = Color(0xFFFFFFFF);
  static const Color backgroundWash = Color(0xFFF0FDF4);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color surfaceLight = Color(0xFFF8FAFC);  // Slate 50
  static const Color surfaceDark = Color(0xFFF1F5F9);   // Slate 100
  static const Color divider = Color(0xFFE2E8F0);       // Slate 200
  static const Color darkCard = Color(0xFF0F172A);      // Slate 900 card

  // ─── Subject Colors ───
  static const Color physics = Color(0xFF6366F1);       // Indigo
  static const Color chemistry = Color(0xFF0EA5E9);     // Sky
  static const Color mathematics = Color(0xFFF59E0B);   // Amber

  // ─── Primary aliases ───
  static const Color primaryLight = greenLight;
  static const Color primarySurface = greenSurface;
  static const Color primaryDark = greenDarkAccent;
  static const Color success = primary;
  static const Color successLight = greenSurface;
  static const Color warning = weak;
  static const Color warningLight = Color(0xFFFFF7ED);
  static const Color error = wrong;
  static const Color errorLight = Color(0xFFFEF2F2);

  // ─── Gradients ───
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [white, backgroundWash],
  );

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF16A34A), Color(0xFF004225)],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF166534), Color(0xFF0F172A)],
  );

  static const LinearGradient physicsGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF818CF8), Color(0xFF6366F1)],
  );

  static const LinearGradient chemistryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF38BDF8), Color(0xFF0EA5E9)],
  );

  static const LinearGradient mathematicsGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
  );
}
