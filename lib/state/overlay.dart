import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart' as acrylic;
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import '../log.dart';

/// Turns the main window into a transparent, click-through, always-on-top
/// karaoke strip over games, and back. Global hotkey: Ctrl+Shift+L.
class GameOverlay extends ChangeNotifier {
  bool active = false;

  /// Set by the app: 'toggle' | 'next' | 'prev'.
  void Function(String action)? onMedia;
  bool _busy = false;
  Rect? _saved;
  bool _wasMaximized = false;

  final _hotKey = HotKey(
    key: PhysicalKeyboardKey.keyL,
    modifiers: [HotKeyModifier.control, HotKeyModifier.shift],
    scope: HotKeyScope.system,
  );

  Future<void> init() async {
    try {
      await hotKeyManager.unregisterAll();
      await hotKeyManager.register(_hotKey, keyDownHandler: (_) => toggle());
    } catch (e) {
      Log.w('hotkey: $e');
    }
  }

  Future<void> toggle() => active ? exit() : enter();

  Future<void> enter() async {
    if (active || _busy) return;
    _busy = true;
    try {
      _wasMaximized = await windowManager.isMaximized();
      if (_wasMaximized) await windowManager.unmaximize();
      _saved = await windowManager.getBounds();
      active = true;
      notifyListeners();
      final display = await screenRetriever.getPrimaryDisplay();
      final size = display.visibleSize ?? display.size;
      const w = 1160.0, h = 200.0;
      await acrylic.Window.setEffect(effect: acrylic.WindowEffect.transparent);
      await windowManager.setBackgroundColor(Colors.transparent);
      await windowManager.setHasShadow(false);
      await windowManager.setAlwaysOnTop(true);
      await windowManager.setMinimumSize(const Size(200, 80));
      await windowManager.setResizable(false);
      await windowManager.setBounds(Rect.fromLTWH((size.width - w) / 2, 18, w, h));
      await windowManager.setIgnoreMouseEvents(true);
    } catch (e) {
      Log.w('overlay enter: $e');
    } finally {
      _busy = false;
    }
  }

  Future<void> exit() async {
    if (!active || _busy) return;
    _busy = true;
    try {
      await windowManager.setIgnoreMouseEvents(false);
      await windowManager.setAlwaysOnTop(false);
      await windowManager.setResizable(true);
      await windowManager.setMinimumSize(const Size(1000, 640));
      await windowManager.setHasShadow(true);
      await acrylic.Window.setEffect(effect: acrylic.WindowEffect.disabled);
      await windowManager.setBackgroundColor(Colors.black);
      if (_saved != null) await windowManager.setBounds(_saved!);
      if (_wasMaximized) await windowManager.maximize();
      active = false;
      notifyListeners();
      await windowManager.focus();
    } catch (e) {
      Log.w('overlay exit: $e');
    } finally {
      _busy = false;
    }
  }
}
