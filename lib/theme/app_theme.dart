import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF216E4E);
  static const Color primaryDark = Color(0xFF14543B);
  static const Color primarySoft = Color(0xFFE5F3EA);
  static const Color surfaceTint = Color(0xFFF1F6F0);
  static const Color background = Color(0xFFFFFFFF);
  static const Color card = Color(0xFFFFFFFF);
  static const Color cardWarm = Color(0xFFFFFBF5);
  static const Color border = Color(0xFFE1E7DE);
  static const Color borderStrong = Color(0xFFD1DCCF);
  static const Color heading = Color(0xFF16231C);
  static const Color body = Color(0xFF425047);
  static const Color muted = Color(0xFF6F7D74);
  static const Color amber = Color(0xFFD97706);
  static const Color amberSoft = Color(0xFFFFF2D6);
  static const Color pink = Color(0xFFC9567B);
  static const Color pinkSoft = Color(0xFFFBE7EF);
  static const Color indigo = Color(0xFF4F5D95);
  static const Color indigoSoft = Color(0xFFE9ECF8);
  static const Color danger = Color(0xFFC6533D);
  static const Color dangerSoft = Color(0xFFFBE8E3);
  static const Color success = Color(0xFF2D7D50);
  static const Color successSoft = Color(0xFFE4F3E9);
}

class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
}

class AppRadii {
  static const double sm = 14;
  static const double md = 18;
  static const double lg = 22;
  static const double xl = 28;
  static const double pill = 999;
}

class AppShadows {
  static List<BoxShadow> card = <BoxShadow>[
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.055),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.03),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> hero(Color color) => <BoxShadow>[
    BoxShadow(
      color: color.withValues(alpha: 0.28),
      blurRadius: 24,
      offset: const Offset(0, 10),
    ),
  ];
}

class AppGradients {
  static const LinearGradient brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[AppColors.primary, AppColors.primaryDark],
  );

  static const LinearGradient brandAlt = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[AppColors.primary, AppColors.indigo],
  );

  static const LinearGradient screen = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[Color(0xFFF4FAF5), Color(0xFFFFFFFF)],
  );

  static const LinearGradient imageScrim = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[Color(0x4D000000), Color(0x12000000), Color(0xCC16231C)],
  );
}

class AppTheme {
  static ThemeData light() {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.indigo,
      onSecondary: Colors.white,
      error: AppColors.danger,
      onError: Colors.white,
      surface: AppColors.card,
      onSurface: AppColors.heading,
      surfaceContainerHighest: AppColors.surfaceTint,
      onSurfaceVariant: AppColors.muted,
      outline: AppColors.borderStrong,
      outlineVariant: AppColors.border,
      shadow: Color(0x14000000),
      scrim: Color(0x52000000),
      inverseSurface: AppColors.heading,
      onInverseSurface: Colors.white,
      inversePrimary: AppColors.primarySoft,
      tertiary: AppColors.amber,
      onTertiary: Colors.white,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'NunitoSans',
    );

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        headlineLarge: const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: AppColors.heading,
          height: 1.08,
          letterSpacing: -0.6,
        ),
        headlineMedium: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: AppColors.heading,
          height: 1.12,
          letterSpacing: -0.45,
        ),
        headlineSmall: const TextStyle(
          fontSize: 23,
          fontWeight: FontWeight.w800,
          color: AppColors.heading,
          height: 1.16,
          letterSpacing: -0.25,
        ),
        titleLarge: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.heading,
          height: 1.25,
          letterSpacing: -0.1,
        ),
        titleMedium: const TextStyle(
          fontSize: 15.5,
          fontWeight: FontWeight.w700,
          color: AppColors.heading,
          height: 1.3,
        ),
        titleSmall: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: AppColors.body,
          letterSpacing: 0.2,
        ),
        bodyLarge: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: AppColors.body,
          height: 1.48,
        ),
        bodyMedium: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
          color: AppColors.body,
          height: 1.45,
        ),
        bodySmall: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.muted,
          height: 1.35,
        ),
        labelLarge: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
        labelSmall: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.35,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.heading,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: AppColors.heading,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.card,
        shadowColor: const Color(0x14000000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.xl),
          side: const BorderSide(color: AppColors.border),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceTint,
        labelStyle: const TextStyle(
          color: AppColors.body,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        hintStyle: const TextStyle(
          color: AppColors.muted,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        helperStyle: const TextStyle(
          color: AppColors.muted,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
        errorStyle: const TextStyle(
          color: AppColors.danger,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.35),
          disabledForegroundColor: Colors.white70,
          minimumSize: const Size.fromHeight(50),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.35),
          disabledForegroundColor: Colors.white70,
          minimumSize: const Size.fromHeight(54),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(44, 44),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.heading,
          side: const BorderSide(color: AppColors.borderStrong),
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.surfaceTint,
        selectedColor: AppColors.primarySoft,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        labelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.body,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(44, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          return Colors.white;
        }),
        checkColor: const WidgetStatePropertyAll(Colors.white),
        side: const BorderSide(color: AppColors.borderStrong, width: 1.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        height: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.xl),
        ),
        titleTextStyle: const TextStyle(
          color: AppColors.heading,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          height: 1.2,
        ),
        contentTextStyle: const TextStyle(
          color: AppColors.body,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          height: 1.45,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.heading,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.md)),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        iconColor: AppColors.primary,
        textColor: AppColors.heading,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        },
      ),
    );
  }
}
