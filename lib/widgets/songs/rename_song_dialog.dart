import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../../bloc/songs/songs_bloc.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/rename_song.dart';

const int _maxTitleLength = 80;

class RenameSongDialog {
  static Future<void> show(
    BuildContext context, {
    required SongModel song,
    required SongsBloc songsBloc,
  }) async {
    final TextEditingController controller = TextEditingController(
      text: song.title,
    );

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        bool submitting = false;
        String? error;

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            Future<void> submit() async {
              final String newTitle = controller.text.trim();
              if (newTitle.isEmpty) {
                setState(() => error = 'Name cannot be empty');
                return;
              }
              setState(() {
                submitting = true;
                error = null;
              });
              final bool ok = await performSongRename(
                song: song,
                newTitle: newTitle,
                songsBloc: songsBloc,
              );
              if (!dialogContext.mounted) {
                return;
              }
              if (ok) {
                Navigator.of(dialogContext).pop();
              } else {
                setState(() {
                  submitting = false;
                  error = 'Could not rename this file';
                });
              }
            }

            return Dialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.r),
                side: const BorderSide(color: AppColors.divider),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(18.w, 20.h, 18.w, 18.h),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Rename track',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16.5.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      'Changes the tag, not the file name',
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 16.h),
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
                              controller: controller,
                              autofocus: true,
                              enabled: !submitting,
                              maxLength: _maxTitleLength,
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
                              decoration: const InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                              ),
                              onSubmitted: (_) => submit(),
                            ),
                          ),
                          InkWell(
                            onTap: controller.clear,
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
                      padding: EdgeInsets.only(top: 6.h),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: ValueListenableBuilder<TextEditingValue>(
                          valueListenable: controller,
                          builder:
                              (
                                BuildContext context,
                                TextEditingValue value,
                                _,
                              ) => Text(
                                '${value.text.length} / $_maxTitleLength',
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
                    if (error != null) ...<Widget>[
                      SizedBox(height: 4.h),
                      Text(
                        error!,
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 12.sp,
                        ),
                      ),
                    ],
                    SizedBox(height: 12.h),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              minimumSize: Size(0, 46.h),
                              side: const BorderSide(color: AppColors.divider),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(13.r),
                              ),
                            ),
                            onPressed: submitting
                                ? null
                                : () => Navigator.of(dialogContext).pop(),
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
                              minimumSize: Size(0, 46.h),
                              backgroundColor: AppColors.accent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(13.r),
                              ),
                            ),
                            onPressed: submitting ? null : submit,
                            child: submitting
                                ? SizedBox(
                                    width: 16.w,
                                    height: 16.w,
                                    child: const CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    'Save',
                                    style: TextStyle(
                                      color: Colors.white,
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
            );
          },
        );
      },
    );
    controller.dispose();
  }
}
