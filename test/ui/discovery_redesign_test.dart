import 'dart:io';
import 'package:insync/screens/auth/onboarding_screen.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    final loader = FontLoader('Roboto');
    loader.addFont(File('test/fixtures/roboto-regular.ttf')
        .readAsBytes()
        .then((bytes) => ByteData.sublistView(bytes)));
    await loader.load();
    final icons = FontLoader('MaterialIcons');
    icons.addFont(File('test/fixtures/materialicons-regular.otf')
        .readAsBytes()
        .then((bytes) => ByteData.sublistView(bytes)));
    await icons.load();
  });
  testWidgets(
      'Onboarding scrolls on a small screen with large text and keyboard',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
            data: const MediaQueryData(
                size: Size(320, 640),
                textScaler: TextScaler.linear(2),
                viewInsets: EdgeInsets.only(bottom: 250)),
            child: const OnboardingScreen())));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('Get started'), 150,
        scrollable: find.byType(Scrollable).first);
    expect(tester.takeException(), isNull);
  });
}
