import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/theme/app_colors.dart';

class SheetShell extends StatelessWidget {
  const SheetShell({
    required this.header,
    required this.body,
    this.showDivider = true,
    super.key,
  });

  final Widget header;
  final Widget body;
  final bool showDivider;

  static const double maxHeightFraction = 0.6;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: maxHeightFraction.sh),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        border: const Border(top: BorderSide(color: AppColors.divider)),
      ),
      padding: EdgeInsets.only(top: 10.h, bottom: 14.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Center(
            child: Container(
              width: 36.w,
              height: 4.h,
              margin: EdgeInsets.only(bottom: 14.h),
              decoration: BoxDecoration(
                color: AppColors.disabled,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          ),
          header,
          if (showDivider)
            Divider(color: AppColors.divider, height: 1.h, thickness: 1),
          Flexible(child: body),
        ],
      ),
    );
  }
}
