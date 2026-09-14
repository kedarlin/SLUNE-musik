import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/theme/app_colors.dart';

/// Shared shape for a bottom sheet that might outgrow the screen: [header]
/// stays pinned at the top and never scrolls, [body] takes whatever space
/// is left and scrolls itself if it doesn't fit - pass a `ListView` or a
/// `SingleChildScrollView` directly as [body], not something that needs an
/// ambient scrollable wrapped around it, since [body] already sits inside a
/// height-constrained `Flexible`. A grey divider marks the boundary.
///
/// Caps the whole sheet at half the screen height - the ceiling every
/// bottom sheet in the app targets, so content past that scrolls instead of
/// pushing the sheet (and the header) off the top of the screen.
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
