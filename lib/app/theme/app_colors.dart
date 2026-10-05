import 'package:flutter/material.dart';

/// Hex colors used across the app.
///
/// MUST be the ONLY file containing hex color definitions.
/// Widgets should access colors via [Theme.of(context)] or [ColorScheme].
abstract class AppColors {
  // Brand Primary - Ocean Blue
  static const Color primaryLight = Color(0xFF1565C0);
  static const Color primaryDark = Color(0xFF64B5F6);

  static const Color primaryDarkToneLight = Color(0xFF0D47A1);
  static const Color primaryDarkToneDark = Color(0xFF42A5F5);

  static const Color primaryLightToneLight = Color(0xFF42A5F5);
  static const Color primaryLightToneDark = Color(0xFF90CAF9);

  static const Color primaryContainerLight = Color(0xFFD6E8FA);
  static const Color primaryContainerDark = Color(0xFF0D3B66);

  // Brand Secondary - Teal
  static const Color secondaryLight = Color(0xFF00897B);
  static const Color secondaryDark = Color(0xFF4DB6AC);

  static const Color secondaryDarkToneLight = Color(0xFF00695C);
  static const Color secondaryDarkToneDark = Color(0xFF00897B);

  static const Color secondaryLightToneLight = Color(0xFF4DB6AC);
  static const Color secondaryLightToneDark = Color(0xFF80CBC4);

  static const Color secondaryContainerLight = Color(0xFFD3EFEB);
  static const Color secondaryContainerDark = Color(0xFF064E47);

  // Neutrals - Background & Surface
  static const Color backgroundLight = Color(0xFFF5F9FC);
  static const Color backgroundDark = Color(0xFF0B1220);

  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF111C2E);

  static const Color surfaceVariantLight = Color(0xFFE8F0F7);
  static const Color surfaceVariantDark = Color(0xFF1B2A3D);

  // Text / Content
  static const Color textPrimaryLight = Color(0xFF172B4D);
  static const Color textPrimaryDark = Color(0xFFF1F5F9);

  static const Color textSecondaryLight = Color(0xFF667085);
  static const Color textSecondaryDark = Color(0xFFA8B3C2);

  // Divider / Border
  static const Color borderLight = Color(0xFFD9E2EC);
  static const Color borderDark = Color(0xFF2A3A4D);

  // Status
  static const Color successLight = Color(0xFF2E7D32);
  static const Color successDark = Color(0xFF66BB6A);

  static const Color warningLight = Color(0xFFF59E0B);
  static const Color warningDark = Color(0xFFFFCA55);

  static const Color errorLight = Color(0xFFD32F2F);
  static const Color errorDark = Color(0xFFEF6C6C);

  // Derived On-Colors (Section 14.5)
  static const Color onPrimaryLight = Color(0xFFFFFFFF);
  static const Color onPrimaryDark = Color(0xFF0B1220);

  static const Color onPrimaryContainerLight = Color(0xFF0D47A1);
  static const Color onPrimaryContainerDark = Color(0xFFCFE6FB);

  static const Color onSecondaryLight = Color(0xFFFFFFFF);
  static const Color onSecondaryDark = Color(0xFF0B1220);

  static const Color onSecondaryContainerLight = Color(0xFF00695C);
  static const Color onSecondaryContainerDark = Color(0xFFCDEFEA);

  static const Color onErrorLight = Color(0xFFFFFFFF);
  static const Color onErrorDark = Color(0xFF0B1220);

  static const Color onSuccessLight = Color(0xFFFFFFFF);
  static const Color onSuccessDark = Color(0xFF0B1220);

  static const Color onWarningLight = Color(0xFF172B4D);
  static const Color onWarningDark = Color(0xFF0B1220);

  static const Color disabledLight = Color(0xFF98A2B3);
  static const Color disabledDark = Color(0xFF5B6B80);
}
