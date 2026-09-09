import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../app_constants/app_enums.dart';
import '../theme/app_colors.dart';

class SortOptionsResult {
  const SortOptionsResult({
    required this.field,
    required this.ascending,
    required this.hideUnderOneMinute,
  });

  final SongSortField field;
  final bool ascending;
  final bool hideUnderOneMinute;
}

class SortOptionsDialog extends StatefulWidget {
  const SortOptionsDialog({
    required this.field,
    required this.ascending,
    required this.hideUnderOneMinute,
    super.key,
  });

  final SongSortField field;
  final bool ascending;
  final bool hideUnderOneMinute;

  static Future<SortOptionsResult?> show(
    BuildContext context, {
    required SongSortField field,
    required bool ascending,
    required bool hideUnderOneMinute,
  }) {
    return showDialog<SortOptionsResult>(
      context: context,
      builder: (BuildContext context) => SortOptionsDialog(
        field: field,
        ascending: ascending,
        hideUnderOneMinute: hideUnderOneMinute,
      ),
    );
  }

  @override
  State<SortOptionsDialog> createState() => _SortOptionsDialogState();
}

class _SortOptionsDialogState extends State<SortOptionsDialog> {
  late SongSortField _field = widget.field;
  late bool _ascending = widget.ascending;
  late bool _hideUnderOneMinute = widget.hideUnderOneMinute;

  static const Map<SongSortField, IconData> _icons = <SongSortField, IconData>{
    SongSortField.title: Icons.sort_by_alpha_rounded,
    SongSortField.length: Icons.slow_motion_video_rounded,
    SongSortField.date: Icons.calendar_today_rounded,
    SongSortField.size: Icons.sd_card_outlined,
  };

  static const Map<SongSortField, String> _labels = <SongSortField, String>{
    SongSortField.title: 'Title',
    SongSortField.length: 'Length',
    SongSortField.date: 'Date',
    SongSortField.size: 'Size',
  };

  List<String> get _directionLabels {
    switch (_field) {
      case SongSortField.title:
        return <String>['A-Z', 'Z-A'];
      case SongSortField.length:
        return <String>['Shortest', 'Longest'];
      case SongSortField.date:
        return <String>['Oldest', 'Newest'];
      case SongSortField.size:
        return <String>['Smallest', 'Largest'];
    }
  }

  Widget _buildFieldOption(SongSortField field) {
    final bool selected = field == _field;
    final Color color = selected ? AppColors.accent : AppColors.textPrimary;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _field = field),
        borderRadius: BorderRadius.circular(8.r),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 8.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(_icons[field], size: 26.sp, color: color),
              SizedBox(height: 8.h),
              Text(
                _labels[field]!,
                style: TextStyle(color: color, fontSize: 14.sp),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDirectionOption({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12.h),
          decoration: BoxDecoration(
            color: selected ? AppColors.transparent : AppColors.surface,
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.transparent,
              width: 1.w,
            ),
            borderRadius: BorderRadius.circular(6.r),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                icon,
                size: 16.sp,
                color: selected ? AppColors.accent : AppColors.textPrimary,
              ),
              SizedBox(width: 6.w),
              Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.accent : AppColors.textPrimary,
                  fontSize: 14.sp,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<String> directions = _directionLabels;

    return Dialog(
      backgroundColor: AppColors.surfaceHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Sort by',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 20.h),
            Row(
              children: SongSortField.values.map(_buildFieldOption).toList(),
            ),
            SizedBox(height: 20.h),
            Row(
              children: <Widget>[
                _buildDirectionOption(
                  label: directions[0],
                  icon: Icons.arrow_upward_rounded,
                  selected: _ascending,
                  onTap: () => setState(() => _ascending = true),
                ),
                _buildDirectionOption(
                  label: directions[1],
                  icon: Icons.arrow_downward_rounded,
                  selected: !_ascending,
                  onTap: () => setState(() => _ascending = false),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Divider(color: AppColors.divider, height: 1.h),
            SizedBox(height: 4.h),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '1 min above',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16.sp,
                    ),
                  ),
                ),
                Switch(
                  value: _hideUnderOneMinute,
                  activeThumbColor: AppColors.white,
                  activeTrackColor: AppColors.accent,
                  onChanged: (bool value) =>
                      setState(() => _hideUnderOneMinute = value),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16.sp,
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(
                    SortOptionsResult(
                      field: _field,
                      ascending: _ascending,
                      hideUnderOneMinute: _hideUnderOneMinute,
                    ),
                  ),
                  child: Text(
                    'Done',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
