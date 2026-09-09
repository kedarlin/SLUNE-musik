import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../app_constants/playlist_constants.dart';

class PlaylistThumbnail extends StatelessWidget {
  const PlaylistThumbnail({
    required this.icon,
    required this.background,
    required this.foreground,
    this.size,
    super.key,
  });

  factory PlaylistThumbnail.user({double? size}) => PlaylistThumbnail(
    icon: Icons.music_note_rounded,
    background: PlaylistColors.userBg,
    foreground: PlaylistColors.userIcon,
    size: size,
  );

  factory PlaylistThumbnail.favourites({double? size}) => PlaylistThumbnail(
    icon: Icons.favorite_rounded,
    background: PlaylistColors.favouritesBg,
    foreground: PlaylistColors.favouritesIcon,
    size: size,
  );

  factory PlaylistThumbnail.recentlyPlayed({double? size}) => PlaylistThumbnail(
    icon: Icons.access_time_filled_rounded,
    background: PlaylistColors.recentBg,
    foreground: PlaylistColors.recentIcon,
    size: size,
  );

  final IconData icon;
  final Color background;
  final Color foreground;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final double tileSize = size ?? 48.w;

    return SizedBox(
      width: tileSize,
      height: tileSize * 1.16,
      child: Stack(
        children: <Widget>[
          Positioned(
            top: 0,
            left: tileSize * 0.06,
            child: Container(
              width: tileSize * 0.62,
              height: tileSize * 0.30,
              decoration: BoxDecoration(
                color: background.withValues(alpha: 0.55),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(6.r),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            child: Container(
              width: tileSize,
              height: tileSize,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(8.r),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: tileSize * 0.5, color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}
