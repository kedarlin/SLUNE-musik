import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/app_colors.dart';

class CustomLoader extends StatelessWidget {
  const CustomLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40.w,
      width: 40.w,
      child: CircularProgressIndicator(
        color: AppColors.white,
        strokeWidth: 2.w,
      ),
    );
  }
}
