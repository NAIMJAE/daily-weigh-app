import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import 'app_text.dart';

/// 웹 MVP와 같은 밀도: 본문 14, 라벨 12, 버튼 높이 44, 얇은 테두리 카드.
class AppTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(seedColor: AppColors.accent, brightness: Brightness.light).copyWith(
      primary: AppColors.accent,
      onPrimary: Colors.white,
      surface: AppColors.card,
      onSurface: AppColors.ink,
      outline: AppColors.line,
      outlineVariant: AppColors.line,
    );

    final radiusButton = BorderRadius.circular(AppRadius.button);
    final radiusChip = BorderRadius.circular(AppRadius.chip);
    final base = ThemeData(useMaterial3: true, fontFamily: AppText.sans);

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.canvas,
      textTheme: base.textTheme
          .copyWith(
            titleLarge: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            titleMedium: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            titleSmall: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            bodyLarge: const TextStyle(fontSize: 15),
            bodyMedium: const TextStyle(fontSize: 14),
            bodySmall: const TextStyle(fontSize: 12, color: AppColors.muted),
            labelLarge: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            labelMedium: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            labelSmall: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          )
          .apply(bodyColor: AppColors.ink, displayColor: AppColors.ink, fontFamily: AppText.sans),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.card,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 52,
        shape: Border(bottom: BorderSide(color: AppColors.line)),
        titleTextStyle: TextStyle(
          fontFamily: AppText.sans,
          color: AppColors.ink,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: const BorderSide(color: AppColors.line),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.card,
        selectedColor: AppColors.chipFill,
        disabledColor: AppColors.mutedBg,
        side: const BorderSide(color: AppColors.line),
        labelStyle: const TextStyle(
          fontFamily: AppText.sans,
          color: AppColors.ink,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: const TextStyle(
          fontFamily: AppText.sans,
          color: AppColors.accent,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        shape: RoundedRectangleBorder(borderRadius: radiusChip),
        showCheckmark: false,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1, space: 24),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.muted,
        textColor: AppColors.ink,
        dense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 4),
        titleTextStyle: TextStyle(
          fontFamily: AppText.sans,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
        subtitleTextStyle: TextStyle(fontFamily: AppText.sans, fontSize: 12, color: AppColors.muted),
      ),
      sliderTheme: const SliderThemeData(activeTrackColor: AppColors.accent, thumbColor: AppColors.accent),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? AppColors.accent : AppColors.faint,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? AppColors.chipFill : AppColors.mutedBg,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.ink,
        contentTextStyle: const TextStyle(fontFamily: AppText.sans, color: Colors.white, fontSize: 13),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: radiusButton),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
        titleTextStyle: const TextStyle(
          fontFamily: AppText.sans,
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: AppColors.ink,
        ),
        contentTextStyle: const TextStyle(fontFamily: AppText.sans, fontSize: 14, color: AppColors.muted, height: 1.5),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet))),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        labelStyle: const TextStyle(fontSize: 13, color: AppColors.muted),
        hintStyle: const TextStyle(fontSize: 13, color: AppColors.faint),
        border: OutlineInputBorder(
          borderRadius: radiusButton,
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radiusButton,
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radiusButton,
          borderSide: const BorderSide(color: AppColors.accent, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.mutedBg,
          minimumSize: const Size.fromHeight(44),
          textStyle: const TextStyle(fontFamily: AppText.sans, fontSize: 14, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: radiusButton),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          minimumSize: const Size.fromHeight(44),
          textStyle: const TextStyle(fontFamily: AppText.sans, fontSize: 14, fontWeight: FontWeight.w600),
          side: const BorderSide(color: AppColors.line),
          shape: RoundedRectangleBorder(borderRadius: radiusButton),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          textStyle: const TextStyle(fontFamily: AppText.sans, fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
