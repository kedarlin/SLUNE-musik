import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'core/theme/theme.dart';
import 'go_router_int.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Import path_provider and get the documents directory
  final Directory appDocumentDir = await getApplicationDocumentsDirectory();
  Hive.init(appDocumentDir.path);
  await Hive.openBox<List<int>>('playlists');
  await Hive.openBox<List<int>>('favorites');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
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
