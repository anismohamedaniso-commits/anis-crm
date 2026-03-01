import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppSpacing {
  // Spacing values
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;

  // Edge insets shortcuts
  static const EdgeInsets paddingXs = EdgeInsets.all(xs);
  static const EdgeInsets paddingSm = EdgeInsets.all(sm);
  static const EdgeInsets paddingMd = EdgeInsets.all(md);
  static const EdgeInsets paddingLg = EdgeInsets.all(lg);
  static const EdgeInsets paddingXl = EdgeInsets.all(xl);

  // Horizontal padding
  static const EdgeInsets horizontalXs = EdgeInsets.symmetric(horizontal: xs);
  static const EdgeInsets horizontalSm = EdgeInsets.symmetric(horizontal: sm);
  static const EdgeInsets horizontalMd = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets horizontalLg = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets horizontalXl = EdgeInsets.symmetric(horizontal: xl);

  // Vertical padding
  static const EdgeInsets verticalXs = EdgeInsets.symmetric(vertical: xs);
  static const EdgeInsets verticalSm = EdgeInsets.symmetric(vertical: sm);
  static const EdgeInsets verticalMd = EdgeInsets.symmetric(vertical: md);
  static const EdgeInsets verticalLg = EdgeInsets.symmetric(vertical: lg);
  static const EdgeInsets verticalXl = EdgeInsets.symmetric(vertical: xl);
}

/// Border radius constants for consistent rounded corners
class AppRadius {
  static const double xs = 6.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double pill = 100.0;
}

// =============================================================================
// TEXT STYLE EXTENSIONS
// =============================================================================

/// Extension to add text style utilities to BuildContext
/// Access via context.textStyles
extension TextStyleContext on BuildContext {
  TextTheme get textStyles => Theme.of(this).textTheme;
}

/// Helper methods for common text style modifications
extension TextStyleExtensions on TextStyle {
  /// Make text bold
  TextStyle get bold => copyWith(fontWeight: FontWeight.bold);

  /// Make text semi-bold
  TextStyle get semiBold => copyWith(fontWeight: FontWeight.w600);

  /// Make text medium weight
  TextStyle get medium => copyWith(fontWeight: FontWeight.w500);

  /// Make text normal weight
  TextStyle get normal => copyWith(fontWeight: FontWeight.w400);

  /// Make text light
  TextStyle get light => copyWith(fontWeight: FontWeight.w300);

  /// Add custom color
  TextStyle withColor(Color color) => copyWith(color: color);

  /// Add custom size
  TextStyle withSize(double size) => copyWith(fontSize: size);

  /// Add letter spacing
  TextStyle withSpacing(double spacing) => copyWith(letterSpacing: spacing);

  /// Add line height
  TextStyle withHeight(double h) => copyWith(height: h);
}

// =============================================================================
// COLORS — Refined warm-neutral palette with coral-orange accent
// =============================================================================

/// Light palette — Tick & Talk brand (White Smoke backgrounds, Neon Orange accent)
class LightModeColors {
  // Primary — Tick & Talk Neon Orange
  static const lightPrimary = Color(0xFFFF7600);
  static const lightOnPrimary = Color(0xFFFFFFFF);
  static const lightPrimaryContainer = Color(0xFFFFEDD5);
  static const lightOnPrimaryContainer = Color(0xFF3D1A00);

  // Secondary — Tick & Talk Dark Gray
  static const lightSecondary = Color(0xFF070707);
  static const lightOnSecondary = Color(0xFFFFFFFF);

  // Tertiary — Tick & Talk medium gray
  static const lightTertiary = Color(0xFF4F4F4F);
  static const lightOnTertiary = Color(0xFFFFFFFF);

  // Error colors
  static const lightError = Color(0xFFBA1A1A);
  static const lightOnError = Color(0xFFFFFFFF);
  static const lightErrorContainer = Color(0xFFFFDAD6);
  static const lightOnErrorContainer = Color(0xFF410002);

  // Surfaces — Tick & Talk White Smoke / clean white
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightOnSurface = Color(0xFF070707);
  static const lightBackground = Color(0xFFF1F1F1);
  static const lightSurfaceVariant = Color(0xFFE8E8E8);
  static const lightOnSurfaceVariant = Color(0xFF4F4F4F);

  // Outline and shadow
  static const lightOutline = Color(0xFFCDCDCD);
  static const lightShadow = Color(0x0A000000);
  static const lightInversePrimary = Color(0xFFCC5F00);
}

/// Status / semantic colors
class AppColors {
  // Accent for badges / highlights
  static const accent = Color(0xFF4A6FA5);

  // Status palette — refined for readability
  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFE5A100);
  static const danger = Color(0xFFDC2626);
  static const info = Color(0xFF2563EB);
  static const neutralDark = Color(0xFF475569);

  // Subtle bg tints for status badges
  static const successBg = Color(0xFFF0FDF4);
  static const warningBg = Color(0xFFFFFBEB);
  static const dangerBg = Color(0xFFFEF2F2);
  static const infoBg = Color(0xFFEFF6FF);
}

/// Dark palette — Tick & Talk Dark Gray surfaces with Neon Orange highlights
class DarkModeColors {
  // Neon Orange — slightly toned for dark backgrounds
  static const darkPrimary = Color(0xFFFF8C1A);
  static const darkOnPrimary = Color(0xFF070707);
  static const darkPrimaryContainer = Color(0xFF3D1A00);
  static const darkOnPrimaryContainer = Color(0xFFFFD0A0);

  // Secondary neutrals — Light Gray
  static const darkSecondary = Color(0xFFCDCDCD);
  static const darkOnSecondary = Color(0xFF070707);

  // Tertiary — medium gray
  static const darkTertiary = Color(0xFF9E9E9E);
  static const darkOnTertiary = Color(0xFF070707);

  // Error colors
  static const darkError = Color(0xFFFFB4AB);
  static const darkOnError = Color(0xFF690005);
  static const darkErrorContainer = Color(0xFF93000A);
  static const darkOnErrorContainer = Color(0xFFFFDAD6);

  // Surfaces — Tick & Talk Dark Gray
  static const darkSurface = Color(0xFF070707);
  static const darkOnSurface = Color(0xFFF1F1F1);
  static const darkSurfaceVariant = Color(0xFF1A1A1A);
  static const darkOnSurfaceVariant = Color(0xFFCDCDCD);

  // Outline and shadow
  static const darkOutline = Color(0xFF282828);
  static const darkShadow = Color(0xFF000000);
  static const darkInversePrimary = Color(0xFFCC5F00);
}

/// Gradients — Tick & Talk brand
class AppGradients {
  static const LinearGradient flame = LinearGradient(
    colors: [Color(0xFFFF8C1A), Color(0xFFFF7600)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient obsidian = LinearGradient(
    colors: [Color(0xFF070707), Color(0xFF111111)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient subtle = LinearGradient(
    colors: [Color(0xFFF1F1F1), Color(0xFFE8E8E8)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

/// Brand assets and tokens
class AppBrand {
  // Expected asset paths. Upload your logos with these filenames via the Assets panel.
  static const String logoBlackAsset = 'assets/brand_logo_black.png';
  static const String logoWhiteAsset = 'assets/brand_logo_white.png';
  static const String name = 'tick & talk';

  /// Small, subtle brand caption style (uses display font)
  static TextStyle caption(BuildContext context) => GoogleFonts.poppins(
        fontSize: FontSizes.labelMedium,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      );
}

/// Font size constants
class FontSizes {
  static const double displayLarge = 52.0;
  static const double displayMedium = 42.0;
  static const double displaySmall = 34.0;
  static const double headlineLarge = 30.0;
  static const double headlineMedium = 26.0;
  static const double headlineSmall = 22.0;
  static const double titleLarge = 20.0;
  static const double titleMedium = 15.0;
  static const double titleSmall = 13.0;
  static const double labelLarge = 14.0;
  static const double labelMedium = 12.0;
  static const double labelSmall = 11.0;
  static const double bodyLarge = 16.0;
  static const double bodyMedium = 14.0;
  static const double bodySmall = 12.0;
}

// =============================================================================
// THEMES
// =============================================================================

/// Light theme — clean, warm, professional
ThemeData get lightTheme => ThemeData(
  useMaterial3: true,
  splashFactory: InkSparkle.splashFactory,
  colorScheme: ColorScheme.light(
    primary: LightModeColors.lightPrimary,
    onPrimary: LightModeColors.lightOnPrimary,
    primaryContainer: LightModeColors.lightPrimaryContainer,
    onPrimaryContainer: LightModeColors.lightOnPrimaryContainer,
    secondary: LightModeColors.lightSecondary,
    onSecondary: LightModeColors.lightOnSecondary,
    tertiary: LightModeColors.lightTertiary,
    onTertiary: LightModeColors.lightOnTertiary,
    error: LightModeColors.lightError,
    onError: LightModeColors.lightOnError,
    errorContainer: LightModeColors.lightErrorContainer,
    onErrorContainer: LightModeColors.lightOnErrorContainer,
    surface: LightModeColors.lightSurface,
    onSurface: LightModeColors.lightOnSurface,
    surfaceContainerHighest: LightModeColors.lightSurfaceVariant,
    onSurfaceVariant: LightModeColors.lightOnSurfaceVariant,
    outline: LightModeColors.lightOutline,
    shadow: LightModeColors.lightShadow,
    inversePrimary: LightModeColors.lightInversePrimary,
  ),
  brightness: Brightness.light,
  scaffoldBackgroundColor: LightModeColors.lightBackground,
  iconTheme: const IconThemeData(color: LightModeColors.lightOnSurface, size: 20),
  appBarTheme: AppBarTheme(
    backgroundColor: Colors.transparent,
    foregroundColor: LightModeColors.lightOnSurface,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: false,
    titleTextStyle: GoogleFonts.poppins(
      fontSize: FontSizes.titleLarge,
      fontWeight: FontWeight.w700,
      color: LightModeColors.lightOnSurface,
    ),
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    color: LightModeColors.lightSurface,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      side: BorderSide(color: LightModeColors.lightOutline.withValues(alpha: 0.4), width: 1),
    ),
    margin: EdgeInsets.zero,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: LightModeColors.lightSurfaceVariant.withValues(alpha: 0.5),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      borderSide: BorderSide(color: LightModeColors.lightOutline.withValues(alpha: 0.5)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      borderSide: BorderSide(color: LightModeColors.lightOutline.withValues(alpha: 0.4)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      borderSide: const BorderSide(color: LightModeColors.lightPrimary, width: 1.5),
    ),
    labelStyle: GoogleFonts.poppins(color: LightModeColors.lightOnSurfaceVariant, fontSize: 13),
    hintStyle: GoogleFonts.poppins(color: LightModeColors.lightOnSurfaceVariant.withValues(alpha: 0.6), fontSize: 13),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    isDense: true,
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: LightModeColors.lightSurface,
    elevation: 0,
    indicatorColor: LightModeColors.lightPrimary.withValues(alpha: 0.12),
    labelTextStyle: WidgetStateProperty.resolveWith((states) {
      final selected = states.contains(WidgetState.selected);
      return GoogleFonts.poppins(
        fontSize: 11,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: selected ? LightModeColors.lightPrimary : LightModeColors.lightOnSurfaceVariant,
      );
    }),
  ),
  navigationRailTheme: NavigationRailThemeData(
    backgroundColor: Colors.transparent,
    indicatorColor: LightModeColors.lightPrimary.withValues(alpha: 0.10),
    selectedIconTheme: const IconThemeData(color: LightModeColors.lightPrimary, size: 22),
    unselectedIconTheme: IconThemeData(color: LightModeColors.lightOnSurfaceVariant.withValues(alpha: 0.7), size: 22),
    selectedLabelTextStyle: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: LightModeColors.lightPrimary),
    unselectedLabelTextStyle: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500, color: LightModeColors.lightOnSurfaceVariant),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: ButtonStyle(
      backgroundColor: const WidgetStatePropertyAll(LightModeColors.lightPrimary),
      foregroundColor: const WidgetStatePropertyAll(LightModeColors.lightOnPrimary),
      shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm))),
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
      textStyle: WidgetStatePropertyAll(GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
      elevation: const WidgetStatePropertyAll(0),
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ButtonStyle(
      backgroundColor: const WidgetStatePropertyAll(LightModeColors.lightPrimary),
      foregroundColor: const WidgetStatePropertyAll(LightModeColors.lightOnPrimary),
      shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm))),
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
      textStyle: WidgetStatePropertyAll(GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
      elevation: const WidgetStatePropertyAll(0),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: ButtonStyle(
      side: WidgetStatePropertyAll(BorderSide(color: LightModeColors.lightOutline.withValues(alpha: 0.6), width: 1)),
      foregroundColor: const WidgetStatePropertyAll(LightModeColors.lightOnSurface),
      shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm))),
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
      textStyle: WidgetStatePropertyAll(GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: ButtonStyle(
      foregroundColor: const WidgetStatePropertyAll(LightModeColors.lightPrimary),
      textStyle: WidgetStatePropertyAll(GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
    ),
  ),
  chipTheme: ChipThemeData(
    labelStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500),
    backgroundColor: LightModeColors.lightSurfaceVariant.withValues(alpha: 0.6),
    selectedColor: LightModeColors.lightPrimary.withValues(alpha: 0.12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xs)),
    side: BorderSide(color: LightModeColors.lightOutline.withValues(alpha: 0.3)),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    iconTheme: const IconThemeData(color: LightModeColors.lightOnSurfaceVariant, size: 16),
  ),
  tabBarTheme: TabBarThemeData(
    indicatorColor: LightModeColors.lightPrimary,
    dividerColor: Colors.transparent,
    labelStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
    unselectedLabelStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
    labelPadding: const EdgeInsets.symmetric(horizontal: 20),
  ),
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: LightModeColors.lightPrimary,
    foregroundColor: LightModeColors.lightOnPrimary,
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
  ),
  dialogTheme: DialogThemeData(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
    surfaceTintColor: Colors.transparent,
    titleTextStyle: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: LightModeColors.lightOnSurface),
  ),
  tooltipTheme: TooltipThemeData(
    decoration: BoxDecoration(
      color: LightModeColors.lightSecondary,
      borderRadius: BorderRadius.circular(AppRadius.xs),
    ),
    textStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.white),
  ),
  dividerTheme: DividerThemeData(
    color: LightModeColors.lightOutline.withValues(alpha: 0.4),
    thickness: 1,
    space: 1,
  ),
  textTheme: _buildTextTheme(Brightness.light),
);

/// Dark theme — rich charcoal with warm orange highlights
ThemeData get darkTheme => ThemeData(
  useMaterial3: true,
  splashFactory: InkSparkle.splashFactory,
  colorScheme: ColorScheme.dark(
    primary: DarkModeColors.darkPrimary,
    onPrimary: DarkModeColors.darkOnPrimary,
    primaryContainer: DarkModeColors.darkPrimaryContainer,
    onPrimaryContainer: DarkModeColors.darkOnPrimaryContainer,
    secondary: DarkModeColors.darkSecondary,
    onSecondary: DarkModeColors.darkOnSecondary,
    tertiary: DarkModeColors.darkTertiary,
    onTertiary: DarkModeColors.darkOnTertiary,
    error: DarkModeColors.darkError,
    onError: DarkModeColors.darkOnError,
    errorContainer: DarkModeColors.darkErrorContainer,
    onErrorContainer: DarkModeColors.darkOnErrorContainer,
    surface: DarkModeColors.darkSurface,
    onSurface: DarkModeColors.darkOnSurface,
    surfaceContainerHighest: DarkModeColors.darkSurfaceVariant,
    onSurfaceVariant: DarkModeColors.darkOnSurfaceVariant,
    outline: DarkModeColors.darkOutline,
    shadow: DarkModeColors.darkShadow,
    inversePrimary: DarkModeColors.darkInversePrimary,
  ),
  brightness: Brightness.dark,
  scaffoldBackgroundColor: DarkModeColors.darkSurface,
  appBarTheme: AppBarTheme(
    backgroundColor: Colors.transparent,
    foregroundColor: DarkModeColors.darkOnSurface,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: false,
    titleTextStyle: GoogleFonts.poppins(
      fontSize: FontSizes.titleLarge,
      fontWeight: FontWeight.w700,
      color: DarkModeColors.darkOnSurface,
    ),
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    color: DarkModeColors.darkSurfaceVariant,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      side: BorderSide(color: DarkModeColors.darkOutline.withValues(alpha: 0.5), width: 1),
    ),
    margin: EdgeInsets.zero,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: DarkModeColors.darkSurfaceVariant,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      borderSide: BorderSide(color: DarkModeColors.darkOutline.withValues(alpha: 0.6)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      borderSide: BorderSide(color: DarkModeColors.darkOutline.withValues(alpha: 0.5)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppRadius.sm)),
      borderSide: const BorderSide(color: DarkModeColors.darkPrimary, width: 1.5),
    ),
    labelStyle: GoogleFonts.poppins(color: DarkModeColors.darkOnSurfaceVariant, fontSize: 13),
    hintStyle: GoogleFonts.poppins(color: DarkModeColors.darkOnSurfaceVariant.withValues(alpha: 0.7), fontSize: 13),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    isDense: true,
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: DarkModeColors.darkSurface,
    elevation: 0,
    indicatorColor: DarkModeColors.darkPrimary.withValues(alpha: 0.12),
    labelTextStyle: WidgetStateProperty.resolveWith((states) {
      final selected = states.contains(WidgetState.selected);
      return GoogleFonts.poppins(
        fontSize: 11,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: selected ? DarkModeColors.darkPrimary : DarkModeColors.darkOnSurfaceVariant,
      );
    }),
  ),
  navigationRailTheme: NavigationRailThemeData(
    backgroundColor: Colors.transparent,
    indicatorColor: DarkModeColors.darkPrimary.withValues(alpha: 0.10),
    selectedIconTheme: const IconThemeData(color: DarkModeColors.darkPrimary, size: 22),
    unselectedIconTheme: IconThemeData(color: DarkModeColors.darkOnSurfaceVariant.withValues(alpha: 0.7), size: 22),
    selectedLabelTextStyle: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: DarkModeColors.darkPrimary),
    unselectedLabelTextStyle: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500, color: DarkModeColors.darkOnSurfaceVariant),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: ButtonStyle(
      backgroundColor: const WidgetStatePropertyAll(DarkModeColors.darkPrimary),
      foregroundColor: const WidgetStatePropertyAll(DarkModeColors.darkOnPrimary),
      shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm))),
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
      textStyle: WidgetStatePropertyAll(GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
      elevation: const WidgetStatePropertyAll(0),
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ButtonStyle(
      backgroundColor: const WidgetStatePropertyAll(DarkModeColors.darkPrimary),
      foregroundColor: const WidgetStatePropertyAll(DarkModeColors.darkOnPrimary),
      shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm))),
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
      textStyle: WidgetStatePropertyAll(GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
      elevation: const WidgetStatePropertyAll(0),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: ButtonStyle(
      side: WidgetStatePropertyAll(BorderSide(color: DarkModeColors.darkOutline.withValues(alpha: 0.6), width: 1)),
      foregroundColor: const WidgetStatePropertyAll(DarkModeColors.darkOnSurface),
      shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm))),
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
      textStyle: WidgetStatePropertyAll(GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: ButtonStyle(
      foregroundColor: const WidgetStatePropertyAll(DarkModeColors.darkPrimary),
      textStyle: WidgetStatePropertyAll(GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
    ),
  ),
  chipTheme: ChipThemeData(
    labelStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500),
    backgroundColor: DarkModeColors.darkSurfaceVariant,
    selectedColor: DarkModeColors.darkPrimary.withValues(alpha: 0.15),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xs)),
    side: BorderSide(color: DarkModeColors.darkOutline.withValues(alpha: 0.4)),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    iconTheme: const IconThemeData(color: DarkModeColors.darkOnSurfaceVariant, size: 16),
  ),
  tabBarTheme: TabBarThemeData(
    indicatorColor: DarkModeColors.darkPrimary,
    dividerColor: Colors.transparent,
    labelStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
    unselectedLabelStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
    labelPadding: const EdgeInsets.symmetric(horizontal: 20),
  ),
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: DarkModeColors.darkPrimary,
    foregroundColor: DarkModeColors.darkOnPrimary,
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
  ),
  dialogTheme: DialogThemeData(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
    surfaceTintColor: Colors.transparent,
    backgroundColor: DarkModeColors.darkSurfaceVariant,
    titleTextStyle: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: DarkModeColors.darkOnSurface),
  ),
  tooltipTheme: TooltipThemeData(
    decoration: BoxDecoration(
      color: DarkModeColors.darkOnSurface,
      borderRadius: BorderRadius.circular(AppRadius.xs),
    ),
    textStyle: GoogleFonts.poppins(fontSize: 12, color: DarkModeColors.darkSurface),
  ),
  dividerTheme: DividerThemeData(
    color: DarkModeColors.darkOutline.withValues(alpha: 0.5),
    thickness: 1,
    space: 1,
  ),
  iconTheme: const IconThemeData(color: DarkModeColors.darkOnSurface, size: 20),
  textTheme: _buildTextTheme(Brightness.dark),
);

/// Build text theme using Poppins throughout (Tick & Talk brand font)
TextTheme _buildTextTheme(Brightness brightness) {
  final baseColor = brightness == Brightness.dark
      ? DarkModeColors.darkOnSurface
      : LightModeColors.lightOnSurface;
  final mutedColor = brightness == Brightness.dark
      ? DarkModeColors.darkOnSurfaceVariant
      : LightModeColors.lightOnSurfaceVariant;

  return TextTheme(
    // Display — Poppins Bold for impact (replaces Neue Power)
    displayLarge: GoogleFonts.poppins(
      fontSize: FontSizes.displayLarge,
      fontWeight: FontWeight.w800,
      letterSpacing: -1.0,
      height: 1.1,
      color: baseColor,
    ),
    displayMedium: GoogleFonts.poppins(
      fontSize: FontSizes.displayMedium,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      height: 1.15,
      color: baseColor,
    ),
    displaySmall: GoogleFonts.poppins(
      fontSize: FontSizes.displaySmall,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.25,
      height: 1.2,
      color: baseColor,
    ),
    // Headlines — Poppins SemiBold
    headlineLarge: GoogleFonts.poppins(
      fontSize: FontSizes.headlineLarge,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
      height: 1.25,
      color: baseColor,
    ),
    headlineMedium: GoogleFonts.poppins(
      fontSize: FontSizes.headlineMedium,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
      height: 1.3,
      color: baseColor,
    ),
    headlineSmall: GoogleFonts.poppins(
      fontSize: FontSizes.headlineSmall,
      fontWeight: FontWeight.w600,
      height: 1.35,
      color: baseColor,
    ),
    // Titles — Poppins SemiBold
    titleLarge: GoogleFonts.poppins(
      fontSize: FontSizes.titleLarge,
      fontWeight: FontWeight.w600,
      height: 1.4,
      color: baseColor,
    ),
    titleMedium: GoogleFonts.poppins(
      fontSize: FontSizes.titleMedium,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
      height: 1.4,
      color: baseColor,
    ),
    titleSmall: GoogleFonts.poppins(
      fontSize: FontSizes.titleSmall,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
      height: 1.4,
      color: baseColor,
    ),
    // Labels — Poppins Regular/Medium
    labelLarge: GoogleFonts.poppins(
      fontSize: FontSizes.labelLarge,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
      color: baseColor,
    ),
    labelMedium: GoogleFonts.poppins(
      fontSize: FontSizes.labelMedium,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.3,
      color: mutedColor,
    ),
    labelSmall: GoogleFonts.poppins(
      fontSize: FontSizes.labelSmall,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.3,
      color: mutedColor,
    ),
    // Body — Poppins Light (300) per brand guidelines
    bodyLarge: GoogleFonts.poppins(
      fontSize: FontSizes.bodyLarge,
      fontWeight: FontWeight.w300,
      letterSpacing: 0.1,
      height: 1.55,
      color: baseColor,
    ),
    bodyMedium: GoogleFonts.poppins(
      fontSize: FontSizes.bodyMedium,
      fontWeight: FontWeight.w300,
      letterSpacing: 0.1,
      height: 1.5,
      color: baseColor.withValues(alpha: 0.92),
    ),
    bodySmall: GoogleFonts.poppins(
      fontSize: FontSizes.bodySmall,
      fontWeight: FontWeight.w300,
      letterSpacing: 0.15,
      height: 1.5,
      color: mutedColor,
    ),
  );
}
