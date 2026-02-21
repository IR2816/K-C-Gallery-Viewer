import 'package:flutter/material.dart';

/// Prinsip 8: Desain visual yang "baik" (tanpa mahal)
///
/// Warna:
/// - Background: dark / neutral
/// - Accent: satu warna (biru / ungu)
/// - Hindari terlalu banyak gradient
///
/// Tipografi:
/// - Title: tegas
/// - Body: readable
/// - Jangan lebih dari 2 font
///
/// Spacing:
/// - Padding konsisten
/// - Card breathing space
/// - UX enak = mata tidak capek
class AppTheme {
  // Warna utama
  static const Color primaryColor = Color(0xFF2196F3); // Blue 600
  static const Color primaryDarkColor = Color(0xFF1976D2); // Blue 700
  static const Color primaryLightColor = Color(0xFF64B5F6); // Blue 400

  // Dark theme colors
  static const Color darkBackgroundColor = Color(0xFF000000); // Pure black
  static const Color darkSurfaceColor = Color(0xFF1A1A1A); // Very dark grey
  static const Color darkCardColor = Color(0xFF2A2A2A); // Dark grey
  static const Color darkElevatedSurfaceColor = Color(
    0xFF333333,
  ); // Medium dark grey

  // Light theme colors
  static const Color lightBackgroundColor = Color(
    0xFFF8F9FA,
  ); // Very light grey
  static const Color lightSurfaceColor = Color(0xFFFFFFFF); // Pure white
  static const Color lightCardColor = Color(0xFFFFFFFF); // White
  static const Color lightElevatedSurfaceColor = Color(
    0xFFF1F3F4,
  ); // Light grey

  // Dark theme text colors
  static const Color darkPrimaryTextColor = Color(0xFFFFFFFF); // Pure white
  static const Color darkSecondaryTextColor = Color(0xFFB0B0B0); // Medium grey
  static const Color darkDisabledTextColor = Color(0xFF666666); // Dark grey
  static const Color darkHintTextColor = Color(0xFF808080); // Grey

  // Light theme text colors
  static const Color lightPrimaryTextColor = Color(0xFF212121); // Dark grey
  static const Color lightSecondaryTextColor = Color(0xFF757575); // Medium grey
  static const Color lightDisabledTextColor = Color(0xFFBDBDBD); // Light grey
  static const Color lightHintTextColor = Color(0xFF9E9E9E); // Grey

  // Backward compatibility - default to dark theme colors for existing code
  static const Color primaryTextColor = darkPrimaryTextColor;
  static const Color secondaryTextColor = darkSecondaryTextColor;
  static const Color backgroundColor = darkBackgroundColor;
  static const Color surfaceColor = darkSurfaceColor;
  static const Color cardColor = darkCardColor;
  static const TextStyle captionStyle = darkCaptionStyle;
  static const TextStyle bodyStyle = darkBodyStyle;
  static const TextStyle titleStyle = darkTitleStyle;
  static const TextStyle subtitleStyle = darkSubtitleStyle;
  static const TextStyle heading1Style = darkHeading1Style;
  static const TextStyle heading2Style = darkHeading2Style;
  static const TextStyle heading3Style = darkHeading3Style;
  static const TextStyle buttonTextStyle = darkButtonTextStyle;
  static const TextStyle tabTextStyle = darkTabTextStyle;

  // Status colors
  static const Color successColor = Color(0xFF4CAF50); // Green
  static const Color warningColor = Color(0xFFFF9800); // Orange
  static const Color errorColor = Color(0xFFF44336); // Red
  static const Color infoColor = Color(0xFF2196F3); // Blue

  // Service colors (untuk badges dan indicators)
  static const Map<String, Color> serviceColors = {
    'fanbox': Color(0xFF2196F3), // Blue
    'patreon': Color(0xFFFF9800), // Orange
    'fantia': Color(0xFF9C27B0), // Purple
    'afdian': Color(0xFF4CAF50), // Green
    'boosty': Color(0xFFF44336), // Red
    'kemono': Color(0xFF2196F3), // Blue
    'coomer': Color(0xFF9C27B0), // Purple
  };

  // Gradients (minimal usage)
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryColor, primaryDarkColor],
  );

  static const LinearGradient darkBackgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [darkBackgroundColor, darkSurfaceColor],
  );

  static const LinearGradient lightBackgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [lightBackgroundColor, lightSurfaceColor],
  );

  // Dark theme text styles
  static const TextStyle darkHeading1Style = TextStyle(
    color: darkPrimaryTextColor,
    fontSize: 32,
    fontWeight: FontWeight.bold,
    height: 1.2,
  );

  static const TextStyle darkHeading2Style = TextStyle(
    color: darkPrimaryTextColor,
    fontSize: 24,
    fontWeight: FontWeight.bold,
    height: 1.2,
  );

  static const TextStyle darkHeading3Style = TextStyle(
    color: darkPrimaryTextColor,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  static const TextStyle darkTitleStyle = TextStyle(
    color: darkPrimaryTextColor,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  static const TextStyle darkSubtitleStyle = TextStyle(
    color: darkPrimaryTextColor,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  static const TextStyle darkBodyStyle = TextStyle(
    color: darkPrimaryTextColor,
    fontSize: 14,
    fontWeight: FontWeight.normal,
    height: 1.5,
  );

  static const TextStyle darkCaptionStyle = TextStyle(
    color: darkSecondaryTextColor,
    fontSize: 12,
    fontWeight: FontWeight.normal,
    height: 1.4,
  );

  static const TextStyle darkButtonTextStyle = TextStyle(
    color: darkPrimaryTextColor,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  static const TextStyle darkTabTextStyle = TextStyle(
    color: darkSecondaryTextColor,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.2,
  );

  // Light theme text styles
  static const TextStyle lightHeading1Style = TextStyle(
    color: lightPrimaryTextColor,
    fontSize: 32,
    fontWeight: FontWeight.bold,
    height: 1.2,
  );

  static const TextStyle lightHeading2Style = TextStyle(
    color: lightPrimaryTextColor,
    fontSize: 24,
    fontWeight: FontWeight.bold,
    height: 1.2,
  );

  static const TextStyle lightHeading3Style = TextStyle(
    color: lightPrimaryTextColor,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  static const TextStyle lightTitleStyle = TextStyle(
    color: lightPrimaryTextColor,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  static const TextStyle lightSubtitleStyle = TextStyle(
    color: lightPrimaryTextColor,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  static const TextStyle lightBodyStyle = TextStyle(
    color: lightPrimaryTextColor,
    fontSize: 14,
    fontWeight: FontWeight.normal,
    height: 1.5,
  );

  static const TextStyle lightCaptionStyle = TextStyle(
    color: lightSecondaryTextColor,
    fontSize: 12,
    fontWeight: FontWeight.normal,
    height: 1.4,
  );

  static const TextStyle lightButtonTextStyle = TextStyle(
    color: lightPrimaryTextColor,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  static const TextStyle lightTabTextStyle = TextStyle(
    color: lightSecondaryTextColor,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.2,
  );

  // Spacing constants
  static const double xsPadding = 4.0;
  static const double smPadding = 8.0;
  static const double mdPadding = 16.0;
  static const double lgPadding = 24.0;
  static const double xlPadding = 32.0;

  static const double xsSpacing = 4.0;
  static const double smSpacing = 8.0;
  static const double mdSpacing = 16.0;
  static const double lgSpacing = 24.0;
  static const double xlSpacing = 32.0;

  // Border radius
  static const double xsRadius = 4.0;
  static const double smRadius = 8.0;
  static const double mdRadius = 12.0;
  static const double lgRadius = 16.0;
  static const double xlRadius = 24.0;

  // Elevations
  static const double noElevation = 0.0;
  static const double smElevation = 2.0;
  static const double mdElevation = 4.0;
  static const double lgElevation = 8.0;

  // Animation durations
  static const Duration fastDuration = Duration(milliseconds: 150);
  static const Duration normalDuration = Duration(milliseconds: 300);
  static const Duration slowDuration = Duration(milliseconds: 500);

  // DYNAMIC THEME HELPERS - Get colors based on current theme
  // (Using existing methods at bottom of file for consistency)

  // DYNAMIC TEXT STYLE HELPERS
  static TextStyle getTitleStyle(BuildContext context) {
    final theme = Theme.of(context);
    return theme.brightness == Brightness.dark
        ? darkTitleStyle
        : lightTitleStyle;
  }

  static TextStyle getBodyStyle(BuildContext context) {
    final theme = Theme.of(context);
    return theme.brightness == Brightness.dark ? darkBodyStyle : lightBodyStyle;
  }

  static TextStyle getCaptionStyle(BuildContext context) {
    final theme = Theme.of(context);
    return theme.brightness == Brightness.dark
        ? darkCaptionStyle
        : lightCaptionStyle;
  }

  static TextStyle getSubtitleStyle(BuildContext context) {
    final theme = Theme.of(context);
    return theme.brightness == Brightness.dark
        ? darkSubtitleStyle
        : lightSubtitleStyle;
  }

  static TextStyle getButtonTextStyle(BuildContext context) {
    final theme = Theme.of(context);
    return theme.brightness == Brightness.dark
        ? darkButtonTextStyle
        : lightButtonTextStyle;
  }

  // Get theme data
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: primaryColor,
        surface: darkSurfaceColor,
        error: errorColor,
        onPrimary: darkPrimaryTextColor,
        onSecondary: darkPrimaryTextColor,
        onSurface: darkPrimaryTextColor,
        onError: darkPrimaryTextColor,
      ),

      // App bar theme
      appBarTheme: const AppBarTheme(
        backgroundColor: darkSurfaceColor,
        foregroundColor: darkPrimaryTextColor,
        elevation: noElevation,
        centerTitle: true,
        titleTextStyle: darkHeading3Style,
      ),

      // Card theme
      cardTheme: CardThemeData(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        shadowColor: Color.fromRGBO(0, 0, 0, 0.1),
        color: darkCardColor,
      ),

      // Elevated button theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: darkPrimaryTextColor,
          elevation: smElevation,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(smRadius)),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: mdPadding,
            vertical: smPadding,
          ),
          textStyle: darkButtonTextStyle,
        ),
      ),

      // Text button theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(smRadius)),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: mdPadding,
            vertical: smPadding,
          ),
          textStyle: darkButtonTextStyle,
        ),
      ),

      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(mdRadius)),
          borderSide: const BorderSide(color: darkSurfaceColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(mdRadius)),
          borderSide: BorderSide(color: darkCardColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(mdRadius)),
          borderSide: const BorderSide(color: primaryColor),
        ),
        hintStyle: darkCaptionStyle,
        labelStyle: darkCaptionStyle,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: mdPadding,
          vertical: smPadding,
        ),
      ),

      // Bottom navigation bar theme
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkSurfaceColor,
        selectedItemColor: primaryColor,
        unselectedItemColor: darkSecondaryTextColor,
        type: BottomNavigationBarType.fixed,
        elevation: mdElevation,
        selectedLabelStyle: darkTabTextStyle,
        unselectedLabelStyle: darkTabTextStyle,
      ),

      // Tab bar theme
      tabBarTheme: const TabBarThemeData(
        labelColor: darkSecondaryTextColor,
        unselectedLabelColor: darkSecondaryTextColor,
        indicatorColor: primaryColor,
        labelStyle: darkTabTextStyle,
        unselectedLabelStyle: darkTabTextStyle,
      ),

      // Icon theme
      iconTheme: const IconThemeData(color: darkSecondaryTextColor, size: 24),

      // Text theme
      textTheme: const TextTheme(
        displayLarge: darkHeading1Style,
        displayMedium: darkHeading2Style,
        displaySmall: darkHeading3Style,
        headlineLarge: darkTitleStyle,
        headlineMedium: darkSubtitleStyle,
        bodyLarge: darkBodyStyle,
        bodyMedium: darkBodyStyle,
        bodySmall: darkCaptionStyle,
        labelLarge: darkButtonTextStyle,
        labelMedium: darkButtonTextStyle,
        labelSmall: darkCaptionStyle,
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: primaryColor,
        surface: lightSurfaceColor,
        error: errorColor,
        onPrimary: lightPrimaryTextColor,
        onSecondary: lightPrimaryTextColor,
        onSurface: lightPrimaryTextColor,
        onError: lightPrimaryTextColor,
      ),

      // App bar theme
      appBarTheme: const AppBarTheme(
        backgroundColor: lightSurfaceColor,
        foregroundColor: lightPrimaryTextColor,
        elevation: noElevation,
        centerTitle: true,
        titleTextStyle: lightHeading3Style,
      ),

      // Card theme
      cardTheme: CardThemeData(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        shadowColor: Color.fromRGBO(0, 0, 0, 0.1),
        color: lightCardColor,
      ),

      // Elevated button theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: lightPrimaryTextColor,
          elevation: smElevation,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(smRadius)),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: mdPadding,
            vertical: smPadding,
          ),
          textStyle: lightButtonTextStyle,
        ),
      ),

      // Text button theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(smRadius)),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: mdPadding,
            vertical: smPadding,
          ),
          textStyle: lightButtonTextStyle,
        ),
      ),

      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSurfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(mdRadius)),
          borderSide: const BorderSide(color: lightSurfaceColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(mdRadius)),
          borderSide: BorderSide(color: lightElevatedSurfaceColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(mdRadius)),
          borderSide: const BorderSide(color: primaryColor),
        ),
        hintStyle: lightCaptionStyle,
        labelStyle: lightCaptionStyle,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: mdPadding,
          vertical: smPadding,
        ),
      ),

      // Bottom navigation bar theme
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: lightSurfaceColor,
        selectedItemColor: primaryColor,
        unselectedItemColor: lightSecondaryTextColor,
        type: BottomNavigationBarType.fixed,
        elevation: mdElevation,
        selectedLabelStyle: lightTabTextStyle,
        unselectedLabelStyle: lightTabTextStyle,
      ),

      // Tab bar theme
      tabBarTheme: const TabBarThemeData(
        labelColor: lightSecondaryTextColor,
        unselectedLabelColor: lightSecondaryTextColor,
        indicatorColor: primaryColor,
        labelStyle: lightTabTextStyle,
        unselectedLabelStyle: lightTabTextStyle,
      ),

      // Icon theme
      iconTheme: const IconThemeData(color: lightSecondaryTextColor, size: 24),

      // Text theme
      textTheme: const TextTheme(
        displayLarge: lightHeading1Style,
        displayMedium: lightHeading2Style,
        displaySmall: lightHeading3Style,
        headlineLarge: lightTitleStyle,
        headlineMedium: lightSubtitleStyle,
        bodyLarge: lightBodyStyle,
        bodyMedium: lightBodyStyle,
        bodySmall: lightCaptionStyle,
        labelLarge: lightButtonTextStyle,
        labelMedium: lightButtonTextStyle,
        labelSmall: lightCaptionStyle,
      ),
    );
  }

  // Helper methods
  static Color getServiceColor(String service) {
    return serviceColors[service.toLowerCase()] ?? primaryColor;
  }

  // Theme-aware color helpers untuk backward compatibility
  static Color getSurfaceColor(BuildContext context) {
    return Theme.of(context).colorScheme.surface;
  }

  static Color getOnSurfaceColor(BuildContext context) {
    return Theme.of(context).colorScheme.onSurface;
  }

  static Color getBackgroundColor(BuildContext context) {
    return Theme.of(context).colorScheme.surface;
  }

  static Color getOnBackgroundColor(BuildContext context) {
    return Theme.of(context).colorScheme.onSurface;
  }

  static Color getPrimaryColor(BuildContext context) {
    return Theme.of(context).colorScheme.primary;
  }

  static Color getShadowColor(BuildContext context, {double opacity = 0.1}) {
    return Theme.of(context).shadowColor.withValues(alpha: opacity);
  }

  static Color getDividerColor(BuildContext context) {
    return Theme.of(context).dividerColor;
  }

  static Color getErrorColor(BuildContext context) {
    return Theme.of(context).colorScheme.error;
  }

  // Helper untuk opacity colors
  static Color getOnSurfaceWithOpacity(BuildContext context, double opacity) {
    return Theme.of(context).colorScheme.onSurface.withValues(alpha: opacity);
  }

  static Color getSurfaceVariant(BuildContext context) {
    return Theme.of(context).colorScheme.surfaceContainerHighest;
  }

  static bool isLightColor(Color color) {
    final luminance = color.computeLuminance();
    return luminance > 0.5;
  }

  static Color getContrastColor(Color backgroundColor) {
    return isLightColor(backgroundColor) ? Colors.black : Colors.white;
  }

  static LinearGradient getCardGradient() {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [darkCardColor, darkElevatedSurfaceColor],
    );
  }

  static LinearGradient getLightCardGradient() {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [lightCardColor, lightElevatedSurfaceColor],
    );
  }

  static BoxShadow getCardShadow() {
    return BoxShadow(
      color: Colors.black.withValues(alpha: 0.1),
      blurRadius: 8,
      offset: const Offset(0, 2),
    );
  }

  static BoxShadow getElevatedShadow() {
    return BoxShadow(
      color: Colors.black.withValues(alpha: 0.2),
      blurRadius: 16,
      offset: const Offset(0, 4),
    );
  }
}
