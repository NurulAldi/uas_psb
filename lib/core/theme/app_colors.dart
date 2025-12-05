import 'package:flutter/material.dart';

/// App Color Palette - Airbnb Inspired
class AppColors {
  // Primary Colors - Airbnb Rausch (Pink/Coral)
  static const Color primary = Color(0xFFFF385C); // Airbnb Rausch
  static const Color primaryDark = Color(0xFFE31C5F);
  static const Color primaryLight = Color(0xFFFF5A5F);
  static const Color primaryHover = Color(0xFFD70466);

  // Secondary Colors
  static const Color secondary = Color(0xFF00A699); // Airbnb Teal
  static const Color secondaryDark = Color(0xFF008A80);
  static const Color secondaryLight = Color(0xFF4ECDC4);

  // Neutral Colors - Airbnb Style
  static const Color background = Color(0xFFFFFFFF); // Pure white
  static const Color backgroundGrey =
      Color(0xFFF7F7F7); // Light grey background
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF222222); // Near black
  static const Color textSecondary = Color(0xFF717171); // Medium grey
  static const Color textTertiary = Color(0xFFB0B0B0); // Light grey
  static const Color border = Color(0xFFDDDDDD); // Light border
  static const Color divider = Color(0xFFEBEBEB);

  // Semantic Colors
  static const Color error = Color(0xFFC13515); // Airbnb error red
  static const Color warning = Color(0xFFFFB400); // Warning yellow
  static const Color success = Color(0xFF008A05); // Success green
  static const Color info = Color(0xFF0A7FFF); // Info blue

  // Dark Mode Colors
  static const Color darkBackground = Color(0xFF000000);
  static const Color darkSurface = Color(0xFF1A1A1A);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFB0B0B0);
  static const Color darkBorder = Color(0xFF2A2A2A);

  // Booking Status Colors
  static const Color statusPending = Color(0xFFFFB400); // Yellow
  static const Color statusConfirmed = Color(0xFF0A7FFF); // Blue
  static const Color statusActive = Color(0xFF008A05); // Green
  static const Color statusCompleted = Color(0xFF717171); // Gray
  static const Color statusCancelled = Color(0xFFC13515); // Red

  // Category Colors (Camera specific)
  static const Color categoryDSLR = Color(0xFFFF385C); // Rausch
  static const Color categoryMirrorless = Color(0xFF8B5CF6); // Purple
  static const Color categoryDrone = Color(0xFF00A699); // Teal
  static const Color categoryLens = Color(0xFFFFB400); // Yellow

  // Overlay
  static const Color overlay = Color(0x80000000); // 50% black
  static const Color overlayLight = Color(0x1A000000); // 10% black

  // Special
  static const Color shadow = Color(0x14000000); // Subtle shadow
  static const Color shadowMedium = Color(0x29000000); // Medium shadow
}
