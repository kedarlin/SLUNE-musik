import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'app_colors.dart';

SliderThemeData appSliderTheme({Color? inactiveColor}) {
  return SliderThemeData(
    trackHeight: 2.w,
    thumbShape: RoundSliderThumbShape(enabledThumbRadius: 7.r),
    overlayShape: RoundSliderOverlayShape(overlayRadius: 14.r),
    activeTrackColor: AppColors.accent,
    thumbColor: AppColors.accent,
    inactiveTrackColor:
        inactiveColor ?? AppColors.textPrimary.withValues(alpha: 0.3),
  );
}
