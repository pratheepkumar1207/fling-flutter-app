import 'package:fling/core/video_edit.dart';
import 'package:fling/screens/create/create_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Every colour filter has a 3x3 matrix and can preview live', () {
    for (final f in MediaFilter.colour.skip(1)) {
      expect(f.matrix!.length, 9, reason: f.name);
      expect(f.preview, isNotNull, reason: f.name);
    }
    expect(MediaFilter.none.preview, isNull);
  });

  test('Cartoon is offered, after recording, not as a live filter', () {
    expect(MediaFilter.all.map((f) => f.name), contains('Cartoon'));
    expect(MediaFilter.colour.any((f) => f.cartoon), isFalse);
    expect(MediaFilter.cartoonLook.preview, isNull);
  });

  testWidgets('Caption step for a reel has its options and Share', (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(const MaterialApp(
      home: CreateCaptionScreen(
          path: 'clip.mp4', isVideo: true, mode: CreateMode.reel),
    ));
    expect(find.text('New reel'), findsOneWidget);
    expect(find.text('Tag people'), findsOneWidget);
    expect(find.text('Allow comments'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Close friends only'), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('Caption step for a story offers close friends', (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(const MaterialApp(
      home: CreateCaptionScreen(
          path: 'clip.mp4', isVideo: true, mode: CreateMode.story),
    ));
    expect(find.text('New story'), findsOneWidget);
    expect(find.text('Close friends only'), findsOneWidget);
    expect(find.text('Tag people'), findsNothing);
  });
}
