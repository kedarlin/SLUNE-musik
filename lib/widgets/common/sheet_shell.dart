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
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeightFraction.sh),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          header,
          if (showDivider)
            Divider(
              color: AppColors.textSecondary.withValues(alpha: 0.25),
              height: 1.h,
              thickness: 1,
            ),
          Flexible(child: body),
        ],
      ),
    );
  }
}
