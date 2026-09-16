import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/app_constants/app_enums.dart';
import '../../core/theme/app_colors.dart';
import '../common/sheet_shell.dart';

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
    return showModalBottomSheet<SortOptionsResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
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

  static const Map<SongSortField, String> _labels = <SongSortField, String>{
    SongSortField.title: 'Title',
    SongSortField.length: 'Length',
    SongSortField.date: 'Date added',
    SongSortField.size: 'File size',
  };

  List<String> get _directionLabels {
    switch (_field) {
      case SongSortField.title:
        return <String>['A→Z', 'Z→A'];
      case SongSortField.length:
        return <String>['Shortest', 'Longest'];
      case SongSortField.date:
        return <String>['Oldest', 'Newest'];
      case SongSortField.size:
        return <String>['Smallest', 'Largest'];
    }
  }

  void _apply() {
    Navigator.of(context).pop(
      SortOptionsResult(
        field: _field,
        ascending: _ascending,
        hideUnderOneMinute: _hideUnderOneMinute,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<String> directions = _directionLabels;

    return SheetShell(
      header: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              'Sort tracks',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            Row(
              children: <Widget>[
                _DirectionChip(
                  label: directions[0],
                  selected: _ascending,
                  onTap: () {
                    setState(() => _ascending = true);
                    _apply();
                  },
                ),
                SizedBox(width: 6.w),
                _DirectionChip(
                  label: directions[1],
                  selected: !_ascending,
                  onTap: () {
                    setState(() => _ascending = false);
                    _apply();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      body: Padding(
        padding: EdgeInsets.fromLTRB(4.w, 4.h, 4.w, 8.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final SongSortField field in SongSortField.values)
              _FieldRow(
                label: _labels[field]!,
                selected: field == _field,
                onTap: () {
                  setState(() => _field = field);
                  _apply();
                },
              ),
            Divider(
              color: AppColors.divider,
              height: 17.h,
              indent: 20.w,
              endIndent: 20.w,
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Hide tracks under 1 minute',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14.5.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Switch(
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    value: _hideUnderOneMinute,
                    activeThumbColor: Colors.white,
                    activeTrackColor: AppColors.accent,
                    inactiveThumbColor: AppColors.textTertiary,
                    inactiveTrackColor: AppColors.surfaceHigh,
                    onChanged: (bool value) {
                      setState(() => _hideUnderOneMinute = value);
                      _apply();
                    },
                  ),
                ],
              ),
            ),
            SizedBox(height: 4.h),
          ],
        ),
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 11.h),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.accent : AppColors.textPrimary,
                fontSize: 14.5.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (selected)
              Icon(Icons.check_rounded, size: 17.sp, color: AppColors.accent),
          ],
        ),
      ),
    );
  }
}

class _DirectionChip extends StatelessWidget {
  const _DirectionChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14.r),
      onTap: onTap,
      child: Container(
        height: 28.h,
        padding: EdgeInsets.symmetric(horizontal: 10.w),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent.withValues(alpha: 0.16)
              : AppColors.surfaceHigh,
          border: selected ? Border.all(color: AppColors.accent) : null,
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5.sp,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? AppColors.accent : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
