import 'package:flutter/material.dart';

/// Centralized color palette for Money Mate.
/// Uses a sophisticated teal-to-violet accent palette with
/// semantic colors for income/expense indicators.
class AppColors {
  AppColors._();

  // ─── Brand Seed ─────────────────────────────────────────────────────
  static const Color primarySeed = Color(0xFF6C63FF);

  // ─── Light Theme Colors ─────────────────────────────────────────────
  static const Color primaryLight = Color(0xFF6C63FF);
  static const Color secondaryLight = Color(0xFF03DAC5);
  static const Color tertiaryLight = Color(0xFFFF6B9D);
  static const Color surfaceLight = Color(0xFFF8F9FE);
  static const Color onSurfaceLight = Color(0xFF1A1B2E);

  // ─── Dark Theme Colors ──────────────────────────────────────────────
  static const Color primaryDark = Color(0xFF8B83FF);
  static const Color secondaryDark = Color(0xFF4EEADB);
  static const Color tertiaryDark = Color(0xFFFF85B1);
  static const Color backgroundDark = Color(0xFF0D0E1A);
  static const Color surfaceDark = Color(0xFF12132A);
  static const Color surfaceContainerDark = Color(0xFF1A1B36);
  static const Color onSurfaceDark = Color(0xFFF0F0FF);

  // ─── Semantic Colors ────────────────────────────────────────────────
  static const Color income = Color(0xFF00D68F);
  static const Color expense = Color(0xFFFF4757);
  static const Color transfer = Color(0xFF5B8DEF);

  // ─── Gradient Presets ───────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6C63FF), Color(0xFF8B83FF)],
  );

  static const LinearGradient incomeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF00D68F), Color(0xFF00E4A0)],
  );

  static const LinearGradient expenseGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF4757), Color(0xFFFF6B81)],
  );

  static const LinearGradient cardGradientDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E1F3B), Color(0xFF16172E)],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6C63FF), Color(0xFFFF6B9D)],
  );

  // ─── Category Colors ───────────────────────────────────────────────
  static const List<Color> categoryColors = [
    Color(0xFF6C63FF), // Violet
    Color(0xFFFF6B9D), // Pink
    Color(0xFF00D68F), // Green
    Color(0xFF5B8DEF), // Blue
    Color(0xFFFFB347), // Orange
    Color(0xFFFF4757), // Red
    Color(0xFF4EEADB), // Teal
    Color(0xFFA855F7), // Purple
    Color(0xFFF59E0B), // Amber
    Color(0xFF06B6D4), // Cyan
    Color(0xFFEC4899), // Magenta
    Color(0xFF84CC16), // Lime
  ];
}
