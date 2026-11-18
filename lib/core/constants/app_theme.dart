import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_fonts.dart';

class AppTheme {
  AppTheme._();

  /// Ensures every route inherits Poppins, including widgets with local [TextStyle]s.
  static Widget poppinsBuilder(BuildContext context, Widget? child) {
    if (child == null) {
      return const SizedBox.shrink();
    }
    return DefaultTextStyle(
      style: AppFonts.poppins(),
      child: child,
    );
  }

  static ThemeData get appTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1D4B8F),
      brightness: Brightness.light,
      surface: Colors.white,
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFFF4F6F8),
    );
    final textTheme = AppFonts.poppinsTextTheme(base.textTheme).apply(
      bodyColor: const Color(0xFF1F2937),
      displayColor: const Color(0xFF0F172A),
    );

    return base.copyWith(
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      dividerColor: const Color(0xFFE5E7EB),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFDDE3EA)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFDDE3EA)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          textStyle: AppFonts.poppins(fontWeight: FontWeight.w700),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        textStyle: AppFonts.poppins(fontSize: 12, color: Colors.white),
        decoration: BoxDecoration(
          color: const Color(0xFF1F2937),
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }

  /// Light theme for modal dialogs and forms on white surfaces.
  static ThemeData lightSurfaceTheme({
    required ColorScheme colorScheme,
    TextStyle? fieldTextStyle,
    Color labelColor = const Color(0xFF374151),
    Color hintColor = const Color(0xFF9CA3AF),
    Color titleColor = const Color(0xFF000000),
    Color cursorColor = const Color(0xFF000000),
    Color selectionColor = const Color(0x335EEAD4),
  }) {
    final fieldStyle = fieldTextStyle ??
        AppFonts.poppins(
          fontSize: 14,
          color: titleColor,
          fontWeight: FontWeight.w500,
        );
    final labelStyle = AppFonts.poppins(color: labelColor);
    final hintStyle = AppFonts.poppins(color: hintColor, fontSize: 14);
    final titleStyle = AppFonts.poppins(color: titleColor);

    final base = ThemeData(
      brightness: Brightness.light,
      colorScheme: colorScheme,
    );
    final poppinsTextTheme = AppFonts.poppinsTextTheme(base.textTheme);

    return base.copyWith(
      textTheme: poppinsTextTheme.copyWith(
        bodyLarge: fieldStyle,
        bodyMedium: fieldStyle,
        titleMedium: titleStyle,
      ),
      primaryTextTheme: poppinsTextTheme,
      inputDecorationTheme: InputDecorationTheme(
        labelStyle: labelStyle,
        floatingLabelStyle: labelStyle,
        hintStyle: hintStyle,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: cursorColor,
        selectionColor: selectionColor,
      ),
      dialogTheme: DialogThemeData(titleTextStyle: titleStyle),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(textStyle: AppFonts.poppins()),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(textStyle: AppFonts.poppins()),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(textStyle: AppFonts.poppins()),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(textStyle: fieldStyle),
    );
  }

  static ThemeData get darkTheme {
    final base = ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.pageStart,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accentBlue,
        surface: AppColors.card,
      ),
      useMaterial3: true,
    );

    final poppinsTextTheme = AppFonts.poppinsTextTheme(base.textTheme).copyWith(
      headlineLarge: AppFonts.poppins(
        fontSize: 56,
        fontWeight: FontWeight.w800,
        height: 1.0,
        color: AppColors.textPrimary,
      ),
    );

    final fieldStyle = AppFonts.poppins(color: AppColors.textPrimary);
    final hintStyle = AppFonts.poppins(
      color: AppColors.textSecondary,
      fontSize: 14,
    );

    return base.copyWith(
      textTheme: poppinsTextTheme,
      primaryTextTheme: poppinsTextTheme,
      appBarTheme: AppBarTheme(
        titleTextStyle: AppFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      dialogTheme: DialogThemeData(
        titleTextStyle: AppFonts.poppins(
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        contentTextStyle: AppFonts.poppins(color: AppColors.textSecondary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        labelStyle: fieldStyle,
        floatingLabelStyle: fieldStyle,
        hintStyle: hintStyle,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(textStyle: AppFonts.poppins()),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(textStyle: AppFonts.poppins()),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(textStyle: AppFonts.poppins()),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(textStyle: fieldStyle),
      listTileTheme: ListTileThemeData(
        titleTextStyle: AppFonts.poppins(color: AppColors.textPrimary),
        subtitleTextStyle: AppFonts.poppins(color: AppColors.textSecondary),
      ),
      chipTheme: base.chipTheme.copyWith(
        labelStyle: AppFonts.poppins(color: AppColors.textPrimary),
      ),
      snackBarTheme: SnackBarThemeData(
        contentTextStyle: AppFonts.poppins(color: AppColors.textPrimary),
      ),
      tooltipTheme: TooltipThemeData(textStyle: AppFonts.poppins(fontSize: 12)),
      dataTableTheme: DataTableThemeData(
        headingTextStyle: AppFonts.poppins(
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        dataTextStyle: AppFonts.poppins(color: AppColors.textSecondary),
      ),
      navigationRailTheme: NavigationRailThemeData(
        selectedLabelTextStyle: AppFonts.poppins(fontSize: 12),
        unselectedLabelTextStyle: AppFonts.poppins(fontSize: 12),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedLabelStyle: AppFonts.poppins(fontSize: 12),
        unselectedLabelStyle: AppFonts.poppins(fontSize: 12),
      ),
      tabBarTheme: TabBarThemeData(
        labelStyle: AppFonts.poppins(fontWeight: FontWeight.w600),
        unselectedLabelStyle: AppFonts.poppins(),
      ),
    );
  }
}
