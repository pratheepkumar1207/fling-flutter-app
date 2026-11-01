import 'dart:ui' as ui;

import 'package:fling/core/face_filters.dart';
import 'package:fling/core/face_tracker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('there are 100 filters with different ids and names', () {
    final all = FaceFilter.all;
    expect(all, hasLength(100));
    expect(all.map((f) => f.id).toSet(), hasLength(100));
    expect(all.map((f) => f.name).toSet(), hasLength(100));
  });

  test('every filter belongs to a group the tray shows', () {
    for (final f in FaceFilter.all) {
      expect(FaceFilter.groups, contains(f.group), reason: f.id);
    }
    for (final g in FaceFilter.groups) {
      expect(FaceFilter.all.where((f) => f.group == g), isNotEmpty, reason: g);
    }
  });

  test('every filter draws without an error', () {
    for (final f in FaceFilter.all) {
      final recorder = ui.PictureRecorder();
      f.paint(ui.Canvas(recorder));
      recorder.endRecording().dispose();
    }
  });

  test('smoothing moves part way to the new pose', () {
    const a = FacePose(0, 0, 0.2, 0);
    const b = FacePose(1, 1, 0.4, 1);
    final mid = a.smoothedTo(b, amount: 0.5);
    expect(mid.x, 0.5);
    expect(mid.y, 0.5);
    expect(mid.width, closeTo(0.3, 1e-9));
    expect(mid.angle, 0.5);
  });

  test('a track row keeps time first', () {
    expect(const FacePose(0.1, 0.2, 0.3, 0.4).toRow(250),
        [250.0, 0.1, 0.2, 0.3, 0.4]);
  });
}
