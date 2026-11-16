import 'package:flutter_test/flutter_test.dart';
import 'package:mono/api/models.dart';
import 'package:mono/state/vibe.dart';

void main() {
  test('lrc parse', () {
    final l = Lyrics.parseLrc('[00:01.50] Привет\n[00:03.00]Мир\n[01:02.10] конец');
    expect(l.lines.length, 3);
    expect(l.lines[2].time, const Duration(milliseconds: 62100));
    expect(l.indexAt(const Duration(seconds: 2)), 0);
    expect(l.indexAt(const Duration(seconds: 0)), -1);
  });
  test('vibe parse', () {
    final p = VibeEngine.parse('вайбовые песни для игры ночью');
    expect(p.tags, containsAll(['для игр', 'ночь', 'спокойное']));
    expect(p.settings.mood, 'active');
    expect(p.queries.first, 'вайбовые песни для игры ночью');
  });
}
