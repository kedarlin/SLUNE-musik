import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

final ThemeData themeData = ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF283343),
    error: Colors.redAccent,
    primary: const Color(0xFF131f2b),
    secondary: const Color(0xFFFEEAE6),
    tertiary: Colors.white,
  ),
  sliderTheme: SliderThemeData(trackHeight: 2.w),
  textTheme: TextTheme(
    titleLarge: TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: 20.sp,
      color: Colors.white,
    ),
    titleMedium: TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: 18.sp,
      color: Colors.white,
    ),
    titleSmall: TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: 16.sp,
      color: Colors.white,
    ),
    bodyLarge: TextStyle(
      fontWeight: FontWeight.w500,
      fontSize: 18.sp,
      color: Colors.white,
    ),
    bodyMedium: TextStyle(
      fontWeight: FontWeight.w500,
      fontSize: 16.sp,
      color: Colors.white,
    ),
    bodySmall: TextStyle(
      fontWeight: FontWeight.w500,
      fontSize: 14.sp,
      color: Colors.white,
    ),
  ),
);
