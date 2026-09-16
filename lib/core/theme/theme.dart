import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'app_colors.dart';

final ThemeData themeData = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: AppColors.background,
  textSelectionTheme: const TextSelectionThemeData(
    cursorColor: AppColors.accent,
    selectionColor: AppColors.textSecondary,
    selectionHandleColor: AppColors.textSecondary,
  ),
  colorScheme: ColorScheme.fromSeed(
    brightness: Brightness.dark,
    seedColor: AppColors.accent,
    error: Colors.redAccent,
    primary: AppColors.accent,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    tertiary: AppColors.textPrimary,
  ),
  sliderTheme: SliderThemeData(
    trackHeight: 2.w,
    activeTrackColor: AppColors.accent,
    inactiveTrackColor: AppColors.divider,
    thumbColor: AppColors.accent,
  ),
  dialogTheme: const DialogThemeData(backgroundColor: AppColors.surface),
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: AppColors.surface,
  ),
  textTheme: TextTheme(
    titleLarge: TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: 20.sp,
      color: AppColors.textPrimary,
    ),
    titleMedium: TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: 18.sp,
      color: AppColors.textPrimary,
    ),
    titleSmall: TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: 16.sp,
      color: AppColors.textPrimary,
    ),
    bodyLarge: TextStyle(
      fontWeight: FontWeight.w500,
      fontSize: 18.sp,
      color: AppColors.textPrimary,
    ),
    bodyMedium: TextStyle(
      fontWeight: FontWeight.w500,
      fontSize: 16.sp,
      color: AppColors.textPrimary,
    ),
    bodySmall: TextStyle(
      fontWeight: FontWeight.w500,
      fontSize: 14.sp,
      color: AppColors.textPrimary,
    ),
  ),
);
