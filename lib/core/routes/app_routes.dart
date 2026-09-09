import '../../view/home_page.dart';

class AppRouter {
  static const String initPage = '/';
  static const String homePage = HomePage.routePath;

  static String playlistDetail(String id) => '$homePage/playlist/$id';
}
