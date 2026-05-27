import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../../view/audio_player.dart';
import '../theme/app_colors.dart';

class Utils {
  static void openPlayerBottomSheet(
    BuildContext context,
    SongModel song,
    int index,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      // useSafeArea: false,
      backgroundColor: AppColors.transparent,
      barrierColor: AppColors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => MusicPlayerPage(index: index),
    );
  }
}
