import 'dart:io';
import 'dart:ui' as ui;

import 'package:fling/core/auth_provider.dart';
import 'package:fling/models/room_models.dart';
import 'package:fling/models/user.dart';
import 'package:fling/screens/party/roster_sheet.dart';
import 'package:fling/theme/app_theme.dart';
import 'package:fling/widgets/insync_attach_sheet.dart';
import 'package:fling/widgets/room_settings_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _FakeAuth extends AuthProvider {
  final User _u = User.fromJson({'id': 'me', 'name': 'Test User'});
  @override
  User? get user => _u;
}

final _key = GlobalKey();

Future<void> _pump(WidgetTester t, Widget home) async {
  t.view.physicalSize = const Size(390, 844);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
    value: _FakeAuth(),
    child: MaterialApp(
      theme: AppTheme.darkWithoutWebFonts(),
      // Whole screen including sheets and dialogs.
      builder: (c, child) => RepaintBoundary(key: _key, child: child),
      home: home,
    ),
  ));
  await t
      .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
  await t.pump(const Duration(milliseconds: 100));
}

Future<void> _snap(WidgetTester t, String name) async {
  await t.pumpAndSettle();
  expect(t.takeException(), isNull);
  final b = _key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await t.runAsync(() async {
    final image = await b.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/design-preview/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Widget _opener(void Function(BuildContext) open) => Scaffold(
      body: Builder(
          builder: (c) => Center(
              child: ElevatedButton(
                  onPressed: () => open(c), child: const Text('open')))),
    );

void main() {
  setUpAll(() async {
    final loader = FontLoader('Roboto');
    loader.addFont(File('test/fixtures/roboto-regular.ttf')
        .readAsBytes()
        .then((bytes) => ByteData.sublistView(bytes)));
    await loader.load();
  });

  testWidgets('People in the room', (t) async {
    await _pump(
        t,
        Scaffold(
          body: RosterSheet(
            roster: [
              RosterEntry(userId: 'h', name: 'Bala', isHost: true, micOn: true),
              RosterEntry(userId: 'me', name: 'Test User', micOn: true),
              RosterEntry(userId: 'c', name: 'Chitra'),
              RosterEntry(userId: 'r', name: 'Ravi'),
            ],
            hostId: 'h',
            isHost: false,
            myUserId: 'me',
            roomType: 'watch',
            activeMics: const ['h', 'me'],
            onInvite: () {},
          ),
        ));
    await _snap(t, 'pop-people');
  });

  testWidgets('Attach sheet', (t) async {
    await _pump(t,
        _opener((c) => showInsyncAttachSheet(c, options: AttachKind.values)));
    await t.tap(find.text('open'));
    await _snap(t, 'pop-attach');
  });

  testWidgets('Room settings sheet', (t) async {
    await _pump(
        t,
        _opener((c) => showRoomSettingsSheet(c,
            room: {'id': 'r1', 'roomType': 'watch', 'visibility': 'friends'},
            onChanged: () {})));
    await t.tap(find.text('open'));
    await _snap(t, 'pop-settings');
  });
}
