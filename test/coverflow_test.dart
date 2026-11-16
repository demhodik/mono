import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mono/ui/widgets/coverflow.dart';
import 'package:mono/ui/widgets/vinyl.dart';
import 'package:mono/ui/widgets/glass.dart';

void main() {
  testWidgets('coverflow + vinyl render without errors', (t) async {
    t.view.physicalSize = const Size(1400, 900);
    t.view.devicePixelRatio = 1;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Column(children: [
          SizedBox(
            height: 466,
            child: CoverFlow(
              items: [for (var i = 0; i < 10; i++) CoverFlowItem(image: '', title: 'Album $i', subtitle: 'Artist')],
              onOpen: (_) {},
              onPlay: (_) {},
              cardSize: 300,
            ),
          ),
          const Row(children: [
            Vinyl(cover: '', size: 200, spinning: true),
            GlassButton(child: Text('x')),
          ]),
        ]),
      ),
    ));
    await t.pump(const Duration(milliseconds: 800));
    await t.drag(find.byType(CoverFlow), const Offset(-300, 0));
    await t.pump(const Duration(milliseconds: 800));
    expect(t.takeException(), isNull);
  });
}
