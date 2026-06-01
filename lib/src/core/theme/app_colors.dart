import 'package:flutter/material.dart';

/// Centralized color palette for Money Mate.
/// Uses a sophisticated teal-to-violet accent palette with
/// semantic colors for income/expense indicators.
class AppColors {
  AppColors._();

  // ─── Brand Seed ─────────────────────────────────────────────────────
  static const Color primarySeed = Color(0xFF10B981); // Emerald Green

  // ─── Light Theme Colors ─────────────────────────────────────────────
  static const Color primaryLight = Color(0xFF10B981);
  static const Color secondaryLight = Color(0xFF34D399);
  static const Color tertiaryLight = Color(0xFFF59E0B);
  static const Color surfaceLight = Color(0xFFF8F9FA); // Off-white/light grey background
  static const Color onSurfaceLight = Color(0xFF111827); // Dark Slate/Near Black

  // ─── Dark Theme Colors ──────────────────────────────────────────────
  static const Color primaryDark = Color(0xFF34D399);
  static const Color secondaryDark = Color(0xFF10B981);
  static const Color tertiaryDark = Color(0xFFFBBF24);
  static const Color backgroundDark = Color(0xFF0F172A); // Dark Slate blue/grey background
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color surfaceContainerDark = Color(0xFF334155);
  static const Color onSurfaceDark = Color(0xFFF8FAFC);

  // ─── Semantic Colors ────────────────────────────────────────────────
  static const Color income = Color(0xFF10B981); // Emerald Green
  static const Color expense = Color(0xFFEF4444); // Rose/Red
  static const Color transfer = Color(0xFF3B82F6); // Blue

  // ─── Gradient Presets ───────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF10B981), Color(0xFF059669)],
  );

  static const LinearGradient incomeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF34D399), Color(0xFF10B981)],
  );

  static const LinearGradient expenseGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF87171), Color(0xFFEF4444)],
  );

  static const LinearGradient cardGradientDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF10B981), Color(0xFF059669)],
  );

  // ─── Category Colors ───────────────────────────────────────────────
  static const List<Color> categoryColors = [
    Color(0xFF3B82F6), // Blue (Transport/Savings)
    Color(0xFFF59E0B), // Amber (Food/Drinks)
    Color(0xFF10B981), // Emerald (Salary/Income)
    Color(0xFFEC4899), // Pink (Shopping)
    Color(0xFF8B5CF6), // Purple (Entertainment)
    Color(0xFFEF4444), // Red (Bills/Utilities)
    Color(0xFF06B6D4), // Cyan (Health/Medical)
    Color(0xFF14B8A6), // Teal (Rent/Housing)
  ];
}
