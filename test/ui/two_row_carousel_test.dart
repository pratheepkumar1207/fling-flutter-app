import 'package:fling/widgets/two_row_carousel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('2-row carousel: tap plays, long-press edits, badges show',
      (t) async {
    final log = <String>[];
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TwoRowCarousel(tiles: [
          CarouselTile(
              title: 'Road trip',
              badge: '12 songs',
              onTap: () => log.add('play'),
              onLongPress: () => log.add('edit')),
          CarouselTile(title: 'Kannaana Kanney', onTap: () => log.add('song')),
          const CarouselTile(title: 'Hukum', badge: 'Added', highlighted: true),
        ]),
      ),
    ));
    expect(find.text('12 songs'), findsOneWidget);
    expect(find.text('Added'), findsOneWidget);
    await t.tap(find.text('Road trip'));
    await t.longPress(find.text('Road trip'));
    await t.tap(find.text('Kannaana Kanney'));
    expect(log, ['play', 'edit', 'song']);
  });
}
