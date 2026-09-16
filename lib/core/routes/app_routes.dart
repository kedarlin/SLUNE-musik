import '../../view/home_page.dart';

class AppRouter {
  static const String initPage = '/';
  static const String homePage = HomePage.routePath;
  static String get settings => '$homePage/settings';

  static String playlistDetail(String id) => '$homePage/playlist/$id';
}
