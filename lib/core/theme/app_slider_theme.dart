import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'app_colors.dart';

/// The single slider look used everywhere in the app - defined once here
/// instead of re-specifying trackHeight/thumbShape/overlayShape at every
/// call site (song position, speed/pitch, equalizer bands, bass boost,
/// virtualizer), so every slider looks and behaves the same.
SliderThemeData appSliderTheme({Color? inactiveColor}) {
  return SliderThemeData(
    trackHeight: 2.w,
    thumbShape: RoundSliderThumbShape(enabledThumbRadius: 7.r),
    overlayShape: RoundSliderOverlayShape(overlayRadius: 14.r),
    activeTrackColor: AppColors.accent,
    thumbColor: AppColors.accent,
    inactiveTrackColor: inactiveColor ?? AppColors.textPrimary.withValues(alpha: 0.3),
  );
}
