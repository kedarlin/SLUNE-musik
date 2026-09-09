import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nested/nested.dart';

import 'core/bloc/music_controller_bloc.dart/music_controller_bloc.dart';
import 'core/bloc/playlists_bloc/playlists_bloc.dart';
import 'core/bloc/songs_bloc/songs_bloc.dart';
import 'core/routes/app_routes.dart';
import 'view/home_page.dart';
import 'view/playlist_detail_page.dart';

class GoRouterInit {
  static GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static String initialLocation = AppRouter.homePage;
  static final RouteObserver<ModalRoute<dynamic>> routeObserver =
      RouteObserver<ModalRoute<dynamic>>();
  static Object? initialExtra;

  static late final SongsBloc songsBloc;
  static late final MusicControllerBloc musicControllerBloc;

  static GoRouter router = GoRouter(
    debugLogDiagnostics: true,
    observers: <NavigatorObserver>[GoRouterInit.routeObserver],
    initialLocation: initialLocation,
    navigatorKey: navigatorKey,
    routes: <RouteBase>[
      ShellRoute(
        builder: (BuildContext context, GoRouterState state, Widget child) {
          return MultiBlocProvider(
            providers: <SingleChildWidget>[
              BlocProvider<SongsBloc>.value(value: songsBloc),
              BlocProvider<MusicControllerBloc>.value(
                value: musicControllerBloc,
              ),
              BlocProvider<PlaylistsBloc>(
                create: (BuildContext context) => PlaylistsBloc(),
              ),
            ],
            child: child,
          );
        },
        routes: <RouteBase>[
          GoRoute(
            path: HomePage.routePath,
            builder:
                (BuildContext context, GoRouterState state) => const HomePage(),
          ),
          GoRoute(
            path: '${HomePage.routePath}/playlist/:id',
            builder:
                (BuildContext context, GoRouterState state) =>
                    PlaylistDetailPage(
                      playlistId: state.pathParameters['id']!,
                    ),
          ),
        ],
      ),
    ],
  );
}
