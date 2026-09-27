import 'package:flutter/material.dart';

class AppTheme {
  static const Color resourceBlue = Color(0xFF3D6BFF);
  static const Color bodyInk = Color(0xFF1B1F2A);
  static const Color lightMenuSurface = Color(0xFFFFFFFF);
  static const Color darkMenuSurface = Color(0xFF1F2937);
  static const Color darkMenuText = Color(0xFFF3F4F6);
  static const Color logoutRed = Color(0xFFD5372B);
  // Primary brand color - iSpeak blue
  static const Color primaryColor = Color(0xFF1D4ED8);

  // Secondary colors
  static const Color accentColor = Color(0xFF3B82F6);
  static const Color backgroundColor = Color(0xFFF9FAFB);

  // Text colors
  static const Color textPrimary = Color(0xFF1D4ED8);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFF9CA3AF);

  // Neutral colors
  static const Color errorColor = Color(0xFFEF4444);
  static const Color successColor = Color(0xFF10B981);
  static const Color warningColor = Color(0xFFF59E0B);

  // Typography
  static const String fontFamily = 'Inter';

  static Color menuSurface(Brightness brightness) =>
      brightness == Brightness.dark ? darkMenuSurface : lightMenuSurface;

  static Color menuText(Brightness brightness) =>
      brightness == Brightness.dark ? darkMenuText : bodyInk;

  static Color menuSurfaceOf(BuildContext context) =>
      menuSurface(Theme.of(context).brightness);

  static Color menuTextOf(BuildContext context) =>
      menuText(Theme.of(context).brightness);

  static ColorScheme colorScheme(Brightness brightness) =>
      ColorScheme.fromSeed(
        seedColor: resourceBlue,
        brightness: brightness,
      ).copyWith(
        primary: resourceBlue,
        secondary: resourceBlue,
        surface: menuSurface(brightness),
        surfaceTint: Colors.transparent,
        onSurface: menuText(brightness),
      );

  static PopupMenuThemeData popupMenuTheme(Brightness brightness) =>
      PopupMenuThemeData(
        color: menuSurface(brightness),
        surfaceTintColor: Colors.transparent,
        textStyle: TextStyle(color: menuText(brightness)),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? resourceBlue
                : menuText(brightness),
          ),
        ),
      );

  static MenuStyle menuStyle(Brightness brightness) => MenuStyle(
    backgroundColor: WidgetStatePropertyAll(menuSurface(brightness)),
    surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
  );

  static ButtonStyle menuButtonStyle(Brightness brightness) => ButtonStyle(
    foregroundColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? resourceBlue
          : menuText(brightness),
    ),
    overlayColor: WidgetStateProperty.resolveWith(
      (states) =>
          states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.focused)
          ? resourceBlue.withValues(alpha: 0.08)
          : Colors.transparent,
    ),
  );

  static TextTheme get textTheme {
    return const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        fontFamily: fontFamily,
        color: textPrimary,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        fontFamily: fontFamily,
        color: textPrimary,
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        fontFamily: fontFamily,
        color: textPrimary,
      ),
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        fontFamily: fontFamily,
        color: textPrimary,
      ),
      titleMedium: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        fontFamily: fontFamily,
        color: textPrimary,
      ),
      titleSmall: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        fontFamily: fontFamily,
        color: textPrimary,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        fontFamily: fontFamily,
        color: textPrimary,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        fontFamily: fontFamily,
        color: textSecondary,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        fontFamily: fontFamily,
        color: textHint,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        fontFamily: fontFamily,
        color: textPrimary,
      ),
      labelMedium: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        fontFamily: fontFamily,
        color: textPrimary,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        fontFamily: fontFamily,
        color: textSecondary,
      ),
    );
  }
}
