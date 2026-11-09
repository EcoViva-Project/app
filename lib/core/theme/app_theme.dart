import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData light() {
    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.brandPrimary,
      onPrimary: AppColors.onPrimary,
      primaryContainer: AppColors.primaryContainer,
      onPrimaryContainer: AppColors.onPrimaryContainer,
      secondary: AppColors.secondary,
      onSecondary: AppColors.onSecondary,
      secondaryContainer: AppColors.brandSecondaryContainer,
      onSecondaryContainer: AppColors.brandDarkAccent,
      tertiary: AppColors.tertiary,
      onTertiary: AppColors.onTertiary,
      tertiaryContainer: AppColors.tertiaryContainer,
      onTertiaryContainer: AppColors.onTertiaryContainer,
      error: AppColors.error,
      onError: AppColors.onError,
      errorContainer: AppColors.errorContainer,
      onErrorContainer: AppColors.onErrorContainer,
      surface: AppColors.brandBackground,
      onSurface: AppColors.brandTextPrimary,
      surfaceContainerHighest: AppColors.surfaceContainerHighest,
      outline: AppColors.outline,
      outlineVariant: AppColors.brandBorder,
      shadow: const Color(0x0D756B5E),
      scrim: Colors.black,
      inverseSurface: AppColors.onSurface,
      onInverseSurface: AppColors.surface,
      inversePrimary: AppColors.brandPrimary,
      surfaceTint: AppColors.surfaceTint,
    );

    return ThemeData(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.brandBackground,
      fontFamily: 'PlusJakartaSans',
      useMaterial3: true,
      cardTheme: CardThemeData(
        color: AppColors.brandSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.brandBorder),
        ),
        margin: EdgeInsets.zero,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.brandSurface,
        selectedItemColor: AppColors.brandDarkAccent,
        unselectedItemColor: AppColors.brandTextSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        // O tamanho dos rótulos (12 nos dois estados) é definido no próprio
        // BottomNavigationBar, em lib/app/app.dart.
        selectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        unselectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w500,
          letterSpacing: -0.2,
        ),
      ),
      dividerColor: AppColors.brandBorder,
      // Botões com o verde escuro da marca: texto branco com contraste alto e
      // estado desabilitado legível, sem precisar estilizar tela a tela.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.brandDarkAccent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.brandSecondaryContainer,
          disabledForegroundColor: AppColors.brandTextSecondary,
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brandDarkAccent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.brandSecondaryContainer,
          disabledForegroundColor: AppColors.brandTextSecondary,
          elevation: 0,
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.brandDarkAccent,
          minimumSize: const Size(48, 48),
          side: const BorderSide(color: AppColors.brandDarkAccent),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.brandDarkAccent,
          minimumSize: const Size(48, 48),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.brandDarkAccent,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.brandSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.brandSurface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
      ),
    );
  }
}
