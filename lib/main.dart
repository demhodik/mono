import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'state/app_state.dart';
import 'ui/login.dart';
import 'ui/shell.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await windowManager.ensureInitialized();

  const options = WindowOptions(
    size: Size(1320, 840),
    minimumSize: Size(1000, 640),
    center: true,
    title: 'Mono',
    backgroundColor: Colors.black,
    titleBarStyle: TitleBarStyle.hidden,
  );
  windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  app = AppState();
  app.boot();
  runApp(const MonoApp());
}

class MonoApp extends StatelessWidget {
  const MonoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mono',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      scaffoldMessengerKey: scaffoldMessengerKey,
      home: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          if (!app.ready) {
            return const Scaffold(
              backgroundColor: Colors.black,
              body: Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)),
            );
          }
          return app.loggedIn ? const Shell() : const LoginScreen();
        },
      ),
    );
  }
}
