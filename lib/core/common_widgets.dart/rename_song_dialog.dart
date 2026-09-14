import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../bloc/songs_bloc/songs_bloc.dart';
import '../theme/app_colors.dart';
import '../utils/rename_song.dart';

/// The "Rename to" dialog - title, a single text field with an inline clear
/// button, Cancel/OK, matching the reference the rename option follows.
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

            return AlertDialog(
              backgroundColor: AppColors.surfaceHigh,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
              title: Text(
                'Rename to',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  TextField(
                    controller: controller,
                    autofocus: true,
                    enabled: !submitting,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15.sp,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 14.w,
                        vertical: 12.h,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.r),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          Icons.cancel_rounded,
                          color: AppColors.textSecondary,
                          size: 20.sp,
                        ),
                        onPressed: controller.clear,
                      ),
                    ),
                    onSubmitted: (_) => submit(),
                  ),
                  if (error != null) ...<Widget>[
                    SizedBox(height: 8.h),
                    Text(
                      error!,
                      style: TextStyle(color: Colors.redAccent, fontSize: 12.sp),
                    ),
                  ],
                ],
              ),
              actionsPadding: EdgeInsets.only(right: 12.w, bottom: 8.h),
              actions: <Widget>[
                TextButton(
                  onPressed: submitting
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14.sp,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: submitting ? null : submit,
                  child: submitting
                      ? SizedBox(
                          width: 16.w,
                          height: 16.w,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.w,
                            color: AppColors.accent,
                          ),
                        )
                      : Text(
                          'OK',
                          style: TextStyle(
                            color: AppColors.accent,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();
  }
}
