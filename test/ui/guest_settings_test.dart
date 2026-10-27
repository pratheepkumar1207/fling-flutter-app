import 'package:fling/core/room_prefs.dart';
import 'package:fling/theme/app_theme.dart';
import 'package:fling/widgets/guest_settings_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('balance maps to voice volume and video factor', () {
    final p = RoomPrefs.instance;
    p.setBalance(0.5);
    expect(p.voiceVolume, 100);
    expect(p.videoFactor, 1);
    p.setBalance(0);
    expect(p.videoFactor, 0);
    expect(p.voiceVolume, 100);
    p.setBalance(1);
    expect(p.voiceVolume, 0);
    expect(p.videoFactor, 1);
    p.setBalance(0.75);
    expect(p.voiceVolume, 50);
    p.setBalance(0.5);
  });

  for (final (size, scale) in [
    (const Size(390, 844), 1.0),
    (const Size(320, 640), 1.6),
  ]) {
    testWidgets('guest settings sheet ${size.width.toInt()}@$scale',
        (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      var left = false;
      await t.pumpWidget(MaterialApp(
        theme: AppTheme.darkWithoutWebFonts(),
        builder: (context, w) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: w!),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showGuestSettingsSheet(context,
                    onStage: true, onLeaveMic: () => left = true),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.text('Your settings'), findsOneWidget);
      expect(find.text('Both at full volume'), findsOneWidget);

      await t.tap(find.text('Push to talk'));
      await t.pump();
      expect(RoomPrefs.instance.pushToTalk, isTrue);
      await t.tap(find.text('Push to talk'));
      await t.pump();
      expect(RoomPrefs.instance.pushToTalk, isFalse);

      await t.scrollUntilVisible(find.text('Leave the mic'), 50);
      await t.tap(find.text('Leave the mic'));
      await t.pumpAndSettle();
      expect(left, isTrue);
    });
  }
}
