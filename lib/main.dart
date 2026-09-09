import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

import 'core/bloc/music_controller_bloc.dart/music_controller_bloc.dart';
import 'core/bloc/songs_bloc/songs_bloc.dart';
import 'core/theme/theme.dart';
import 'go_router_int.dart';
import 'service/muxic_audio_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final Directory appDocumentDir = await getApplicationDocumentsDirectory();
  Hive.init(appDocumentDir.path);
  await Hive.openBox<Map<dynamic, dynamic>>('playlists');
  await Hive.openBox<List<int>>('favorites');
  await Hive.openBox<dynamic>('settings');

  final SongsBloc songsBloc = SongsBloc();
  final MusicControllerBloc musicControllerBloc = MusicControllerBloc(songsBloc);

  final MuxicAudioHandler handler = await AudioService.init(
    builder: () => MuxicAudioHandler(musicControllerBloc),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.example.music.playback',
      androidNotificationChannelName: 'Playback',
      androidNotificationOngoing: true,
    ),
  );

  musicControllerBloc.audioHandler = handler;
  await handler.configureSession();

  GoRouterInit.songsBloc = songsBloc;
  GoRouterInit.musicControllerBloc = musicControllerBloc;

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      builder: (BuildContext context, Widget? widget) {
        ScreenUtil.init(
          context,
          designSize: const Size(390, 840),
          minTextAdapt: true,
        );
        return Theme(
          data: themeData,
          child: MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.noScaling),
            child: widget!,
          ),
        );
      },
      routerConfig: GoRouterInit.router,
      debugShowCheckedModeBanner: false,
    );
  }
}
