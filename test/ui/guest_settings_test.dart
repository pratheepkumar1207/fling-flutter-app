import 'package:insync/core/room_prefs.dart';
import 'package:insync/theme/app_theme.dart';
import 'package:insync/widgets/guest_settings_sheet.dart';
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
    testWidgets('guest settings sheet ${size.width.toInt()}@$scale', (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      var reported = false;
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
                    onReport: () => reported = true),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      // Sound bar, the personal tiles and Report room; no titles.
      expect(find.text('Voices louder'), findsOneWidget);
      expect(find.text('Video louder'), findsOneWidget);
      expect(find.text('Your settings'), findsNothing);
      expect(find.text('Leave the mic'), findsNothing);

      await t.tap(find.text('Hold mic button to talk'));
      await t.pump();
      expect(RoomPrefs.instance.pushToTalk, isTrue);
      await t.tap(find.text('Hold mic button to talk'));
      await t.pump();
      expect(RoomPrefs.instance.pushToTalk, isFalse);

      // Swiping up opens the sheet full screen, then scrolls it.
      await t.dragUntilVisible(find.text('Report room'), find.byType(ListView),
          const Offset(0, -150));
      await t.pumpAndSettle();
      await t.tap(find.text('Report room'));
      await t.pumpAndSettle();
      expect(reported, isTrue);
    });
  }
}
