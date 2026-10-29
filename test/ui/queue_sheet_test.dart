import 'package:fling/screens/party/queue_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _item(String title,
        {String? by, String src = 'youtube'}) =>
    {'title': title, 'videoUrl': 'u-$title', 'sourceType': src, 'addedBy': by};

Widget _sheet({required bool host, List<int>? calls}) => MaterialApp(
      home: Scaffold(
        body: QueueSheetScreen(
          roomId: 'r1',
          queue: {
            'currentIndex': 1,
            'items': [
              _item('Old trailer'),
              _item('Moththa Raathiri', src: 'netflix', by: 'b'),
              _item('Anirudh hits live', by: 'r'),
              _item('Lofi Tamil mix', by: 'c'),
            ],
          },
          isHost: host,
          participantCount: 6,
          onAdd: (_, {position = 'bottom'}) {},
          onJump: (i) => calls?.add(i),
          onRemove: (i) => calls?.add(100 + i),
          onReorder: (a, b) => calls?.add(1000 + a * 10 + b),
          onOpenRoster: () {},
          onSwitchSource: (a, b, {videoTitle, videoThumbnail}) async {},
          nameFor: (id) => {'b': 'Bala Kumar', 'r': 'Ravi', 'c': 'Chitra'}[id],
        ),
      ),
    );

void main() {
  testWidgets('Queue sheet follows the design', (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final calls = <int>[];
    await t.pumpWidget(_sheet(host: true, calls: calls));
    expect(find.text('Up next'), findsOneWidget);
    expect(find.text('Search YouTube or paste a link'), findsOneWidget);
    expect(find.text('Queue · 4'), findsOneWidget);
    expect(find.text('Suggested'), findsOneWidget);
    expect(find.text('Audio only'), findsOneWidget);
    expect(find.text('NOW PLAYING'), findsOneWidget);
    expect(find.text('Netflix · added by Bala'), findsOneWidget);
    expect(find.text('UP NEXT · 2'), findsOneWidget);
    expect(find.text('YouTube · added by Ravi'), findsOneWidget);
    expect(find.text('PLAYED'), findsOneWidget);
    // Last one can move up to play next.
    await t.tap(find.byTooltip('Move to top'));
    expect(calls, [1032]);
  });

  testWidgets('Listeners without add rights only see the queue', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: QueueSheetScreen(
          roomId: 'r1',
          queue: const {'currentIndex': 0, 'items': []},
          isHost: false,
          participantCount: 2,
          canAddSongs: false,
          onAdd: (_, {position = 'bottom'}) {},
          onJump: (_) {},
          onRemove: (_) {},
          onReorder: (_, __) {},
          onOpenRoster: () {},
          onSwitchSource: (a, b, {videoTitle, videoThumbnail}) async {},
        ),
      ),
    ));
    expect(find.text('Search YouTube or paste a link'), findsNothing);
    expect(find.text('The host picks what plays here'), findsOneWidget);
    expect(find.byTooltip('Remove'), findsNothing);
  });
}
