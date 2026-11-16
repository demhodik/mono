import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  app.overlay.onMedia = (a) {
    final p = app.player;
    if (a == 'toggle') p.toggle();
    if (a == 'next') p.next();
    if (a == 'prev') p.previous();
  };
  app.overlay.init();
  HardwareKeyboard.instance.addHandler(_onKey);
  runApp(const MonoApp());
}

/// App-wide keyboard shortcuts (ignored while typing in a text field).
bool _onKey(KeyEvent e) {
  if (e is! KeyDownEvent || !app.loggedIn || app.overlay.active) return false;
  final k = e.logicalKey;
  final p = app.player;
  final ctrl = HardwareKeyboard.instance.isControlPressed;
  final shift = HardwareKeyboard.instance.isShiftPressed;
  final typing = FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<EditableText>() != null;

  if (k == LogicalKeyboardKey.escape) {
    if (typing) {
      FocusManager.instance.primaryFocus?.unfocus();
      return true;
    }
    if (app.nowPlaying) {
      app.setNowPlaying(false);
      return true;
    }
    return false;
  }
  if (ctrl && !shift && k == LogicalKeyboardKey.keyF) {
    app.search(app.searchQuery);
    app.searchFocus.requestFocus();
    return true;
  }
  if (typing) return false;
  if (k == LogicalKeyboardKey.space) {
    p.toggle();
    return true;
  }
  if (ctrl && k == LogicalKeyboardKey.arrowRight) {
    p.next();
    return true;
  }
  if (ctrl && k == LogicalKeyboardKey.arrowLeft) {
    p.previous();
    return true;
  }
  if (ctrl && k == LogicalKeyboardKey.arrowUp) {
    p.setVolume(p.volume + 5);
    return true;
  }
  if (ctrl && k == LogicalKeyboardKey.arrowDown) {
    p.setVolume(p.volume - 5);
    return true;
  }
  if (!ctrl && k == LogicalKeyboardKey.arrowRight && p.current != null) {
    p.seek(p.position.value + const Duration(seconds: 5));
    return true;
  }
  if (!ctrl && k == LogicalKeyboardKey.arrowLeft && p.current != null) {
    final t = p.position.value - const Duration(seconds: 5);
    p.seek(t < Duration.zero ? Duration.zero : t);
    return true;
  }
  if (!ctrl && k == LogicalKeyboardKey.keyF && p.current != null) {
    app.setNowPlaying(!app.nowPlaying);
    return true;
  }
  if (!ctrl && k == LogicalKeyboardKey.keyL && p.current != null) {
    app.toggleLike(p.current!);
    return true;
  }
  if (!ctrl && k == LogicalKeyboardKey.keyM) {
    p.toggleMute();
    return true;
  }
  return false;
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
