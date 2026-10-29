import 'package:fling/widgets/view_once.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _img =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

void main() {
  testWidgets('View-once viewer closes itself after 10 seconds',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const ViewOnceViewer(mediaUrl: _img))),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('View once · 10s'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 3600));
    expect(find.text('View once · 6s'), findsOneWidget);
    await tester.pump(const Duration(seconds: 7));
    await tester.pumpAndSettle();
    expect(find.byType(ViewOnceViewer), findsNothing);
  });

  testWidgets('View-once chip says what you can do', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(children: [
          ViewOnceChip(mine: false, opened: false, onOpen: () => taps++),
          const ViewOnceChip(mine: false, opened: true),
          const ViewOnceChip(mine: true, opened: false),
        ]),
      ),
    ));
    expect(find.text('Tap to view · 10s'), findsOneWidget);
    expect(find.text('Opened'), findsOneWidget);
    expect(find.text('View once photo'), findsOneWidget);
    await tester.tap(find.text('Tap to view · 10s'));
    expect(taps, 1);
  });
}
