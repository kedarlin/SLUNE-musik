import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/app_colors.dart';

class CreatePlaylistSheet extends StatefulWidget {
  const CreatePlaylistSheet({
    this.title = 'Create New Playlist',
    this.actionLabel = 'Create',
    this.initialValue,
    super.key,
  });

  final String title;
  final String actionLabel;
  final String? initialValue;

  static Future<String?> show(
    BuildContext context, {
    String title = 'Create New Playlist',
    String actionLabel = 'Create',
    String? initialValue,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (BuildContext context) => CreatePlaylistSheet(
        title: title,
        actionLabel: actionLabel,
        initialValue: initialValue,
      ),
    );
  }

  @override
  State<CreatePlaylistSheet> createState() => _CreatePlaylistSheetState();
}

class _CreatePlaylistSheetState extends State<CreatePlaylistSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );
  late bool _canCreate = (widget.initialValue ?? '').trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final bool canCreate = _controller.text.trim().isNotEmpty;
      if (canCreate != _canCreate) {
        setState(() => _canCreate = canCreate);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_canCreate) {
      return;
    }
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 20.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.playlist_add_rounded,
                  size: 24.sp,
                  color: AppColors.textPrimary,
                ),
                SizedBox(width: 12.w),
                Text(
                  widget.title,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20.h),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15.sp,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Enter Playlist Name',
                      hintStyle: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 15.sp,
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 14.w,
                        vertical: 14.h,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                        borderSide: const BorderSide(color: AppColors.divider),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                        borderSide: const BorderSide(color: AppColors.accent),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                TextButton(
                  onPressed: _canCreate ? _submit : null,
                  style: TextButton.styleFrom(
                    backgroundColor: _canCreate
                        ? AppColors.accent
                        : AppColors.surface,
                    padding: EdgeInsets.symmetric(
                      horizontal: 20.w,
                      vertical: 16.h,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  child: Text(
                    widget.actionLabel,
                    style: TextStyle(
                      color: _canCreate
                          ? AppColors.white
                          : AppColors.textSecondary,
                      fontSize: 15.sp,
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
