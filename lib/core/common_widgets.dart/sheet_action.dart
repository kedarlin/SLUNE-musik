import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/app_colors.dart';

class SheetAction extends StatelessWidget {
  const SheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, size: 24.sp, color: AppColors.textPrimary),
      title: Text(
        label,
        style: TextStyle(fontSize: 16.sp, color: AppColors.textPrimary),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 20.w),
      onTap: onTap,
    );
  }
}
