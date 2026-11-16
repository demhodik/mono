import 'package:flutter/material.dart';

/// Monochrome palette (Spotify-like layout, black & white).
class C {
  static const bg = Color(0xFF000000);
  static const panel = Color(0xFF121212);
  static const panelHi = Color(0xFF1A1A1A);
  static const hover = Color(0xFF2A2A2A);
  static const line = Color(0xFF2E2E2E);
  static const text = Color(0xFFFFFFFF);
  static const sub = Color(0xFFA7A7A7);
  static const dim = Color(0xFF6A6A6A);
}

ThemeData buildTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: C.bg,
    colorScheme: const ColorScheme.dark(
      primary: Colors.white,
      onPrimary: Colors.black,
      secondary: Colors.white,
      surface: C.panel,
      onSurface: C.text,
    ),
    textTheme: base.textTheme.apply(bodyColor: C.text, displayColor: C.text, fontFamily: 'Manrope'),
    sliderTheme: const SliderThemeData(
      trackHeight: 4,
      activeTrackColor: Colors.white,
      inactiveTrackColor: Color(0xFF4D4D4D),
      thumbColor: Colors.white,
      overlayShape: RoundSliderOverlayShape(overlayRadius: 10),
      thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
      overlayColor: Colors.transparent,
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(Colors.white.withValues(alpha: 0.25)),
      radius: const Radius.circular(8),
      thickness: const WidgetStatePropertyAll(8),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Colors.white,
      contentTextStyle: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: C.hover, borderRadius: BorderRadius.circular(6)),
      textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      waitDuration: const Duration(milliseconds: 500),
    ),
    textSelectionTheme: const TextSelectionThemeData(cursorColor: Colors.white, selectionColor: Color(0x55FFFFFF)),
  );
}

String fmt(Duration d) {
  final m = d.inMinutes;
  final s = d.inSeconds % 60;
  if (m >= 60) return '${m ~/ 60}:${(m % 60).toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  return '$m:${s.toString().padLeft(2, '0')}';
}

String plural(int n, String one, String few, String many) {
  final m10 = n % 10, m100 = n % 100;
  if (m10 == 1 && m100 != 11) return '$n $one';
  if (m10 >= 2 && m10 <= 4 && (m100 < 10 || m100 >= 20)) return '$n $few';
  return '$n $many';
}
