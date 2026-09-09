import 'dart:ui';

class BuiltInPlaylists {
  static const String favourites = '__favourites__';
  static const String recentlyPlayed = '__recently_played__';

  static bool isBuiltIn(String id) =>
      id == favourites || id == recentlyPlayed;
}

class PlaylistColors {
  static const Color favouritesBg = Color(0xFFF0DAD8);
  static const Color favouritesIcon = Color(0xFFE0433F);

  static const Color recentBg = Color(0xFFE4D6A7);
  static const Color recentIcon = Color(0xFFF0A500);

  static const Color userBg = Color(0xFFF5E9FF);
  static const Color userIcon = Color(0xFFB85FFF);
}
