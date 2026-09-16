import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/theme/app_colors.dart';
import '../common/sheet_shell.dart';

const int _maxNameLength = 40;

class CreatePlaylistSheet extends StatefulWidget {
  const CreatePlaylistSheet({
    this.title = 'New playlist',
    this.subtitle = 'Speed and pitch can be pinned to it later',
    this.actionLabel = 'Create',
    this.initialValue,
    super.key,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final String? initialValue;

  static Future<String?> show(
    BuildContext context, {
    String title = 'New playlist',
    String subtitle = 'Speed and pitch can be pinned to it later',
    String actionLabel = 'Create',
    String? initialValue,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => CreatePlaylistSheet(
        title: title,
        subtitle: subtitle,
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
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SheetShell(
        showDivider: false,
        header: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                widget.title,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 3.h),
              Text(
                widget.subtitle,
                style: TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 12.5.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        body: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 4.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                height: 44.h,
                padding: EdgeInsets.symmetric(horizontal: 14.w),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(13.r),
                  border: Border.all(color: AppColors.accent),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        autofocus: true,
                        maxLength: _maxNameLength,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                        buildCounter:
                            (
                              _, {
                              required int currentLength,
                              required bool isFocused,
                              required int? maxLength,
                            }) => null,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: 'Playlist name',
                          hintStyle: TextStyle(
                            color: AppColors.disabled,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: _controller.clear,
                      child: Icon(
                        Icons.close_rounded,
                        size: 16.sp,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.only(top: 6.h, bottom: 18.h),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _controller,
                    builder: (BuildContext context, TextEditingValue value, _) =>
                        Text(
                          '${value.text.length} / $_maxNameLength',
                          style: TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 11.5.sp,
                            fontWeight: FontWeight.w500,
                            fontFeatures: const <FontFeature>[
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                  ),
                ),
              ),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: Size(0, 48.h),
                        side: const BorderSide(color: AppColors.divider),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13.r),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13.5.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(0, 48.h),
                        backgroundColor: _canCreate
                            ? AppColors.accent
                            : AppColors.surfaceHigh,
                        disabledBackgroundColor: AppColors.surfaceHigh,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13.r),
                        ),
                      ),
                      onPressed: _canCreate ? _submit : null,
                      child: Text(
                        widget.actionLabel,
                        style: TextStyle(
                          color: _canCreate
                              ? Colors.white
                              : AppColors.disabled,
                          fontSize: 13.5.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
