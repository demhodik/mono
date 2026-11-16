import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart' as acrylic;
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'log.dart';
import 'state/app_state.dart';
import 'ui/intro.dart';
import 'ui/lyrics.dart';
import 'ui/login.dart';
import 'ui/shell.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Log.init();
  Log.w('start');
  FlutterError.onError = (d) => Log.w('flutter error: ${d.exceptionAsString()}\n${d.stack}');
  PlatformDispatcher.instance.onError = (e, st) {
    Log.w('uncaught: $e\n$st');
    return true;
  };
  MediaKit.ensureInitialized();
  await windowManager.ensureInitialized();
  try {
    await acrylic.Window.initialize();
  } catch (e) {
    Log.w('acrylic: $e');
  }

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
  app.overlay.init();
  runApp(const MonoApp());
}

class MonoApp extends StatefulWidget {
  const MonoApp({super.key});

  @override
  State<MonoApp> createState() => _MonoAppState();
}

class _MonoAppState extends State<MonoApp> {
  bool _intro = true;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mono',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      scaffoldMessengerKey: scaffoldMessengerKey,
      color: Colors.transparent,
      builder: (context, child) => ListenableBuilder(
        listenable: app.overlay,
        builder: (context, _) {
          final ov = app.overlay.active;
          return Stack(children: [
            Offstage(offstage: ov, child: TickerMode(enabled: !ov, child: child!)),
            if (ov)
              const Material(
                type: MaterialType.transparency,
                child: Align(alignment: Alignment.topCenter, child: Padding(padding: EdgeInsets.fromLTRB(20, 6, 20, 0), child: OverlayLyrics())),
              ),
            if (_intro && !ov) IntroOverlay(onDone: () => setState(() => _intro = false)),
          ]);
        },
      ),
      home: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          if (!app.ready) {
            return const Scaffold(
              backgroundColor: Colors.black,
              body: SizedBox.shrink(),
            );
          }
          return app.loggedIn ? const Shell() : const LoginScreen();
        },
      ),
    );
  }
}
