import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('orb shader loads', (t) async {
    final p = await ui.FragmentProgram.fromAsset('shaders/orb.frag');
    final s = p.fragmentShader();
    for (var i = 0; i < 6; i++) {
      s.setFloat(i, 1);
    }
    expect(s, isNotNull);
  });
}
