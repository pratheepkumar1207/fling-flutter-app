import 'dart:io';
import 'dart:ui' as ui;

import 'package:fling/screens/auth/login_screen.dart';
import 'package:fling/screens/auth/onboarding_screen.dart';
import 'package:fling/screens/auth/otp_screen.dart';
import 'package:fling/screens/auth/safety_guidelines_screen.dart';
import 'package:fling/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// The app theme, with Roboto standing in for Plus Jakarta Sans (no network
// font fetching in tests).
ThemeData _theme() => AppTheme.darkWithoutWebFonts();

Future<void> _render(WidgetTester tester, Widget screen, String name,
    {Size size = const Size(390, 844), double textScale = 1}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final key = GlobalKey();
  await tester.pumpWidget(MaterialApp(
    theme: _theme(),
    home: MediaQuery(
      data:
          MediaQueryData(size: size, textScaler: TextScaler.linear(textScale)),
      child: RepaintBoundary(key: key, child: screen),
    ),
  ));
  await tester
      .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
  await tester.pump(const Duration(milliseconds: 100));
  expect(tester.takeException(), isNull);
  if (textScale != 1) return;
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/design-preview/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    final loader = FontLoader('Roboto');
    loader.addFont(File('test/fixtures/roboto-regular.ttf')
        .readAsBytes()
        .then((bytes) => ByteData.sublistView(bytes)));
    await loader.load();
  });

  testWidgets(
      'Front page', (t) => _render(t, const OnboardingScreen(), 'auth-front'));
  testWidgets('Sign in', (t) => _render(t, const LoginScreen(), 'auth-signin'));
  testWidgets(
      'Enter code',
      (t) =>
          _render(t, const OtpScreen(phone: '+91 98765 43210'), 'auth-code'));
  testWidgets(
      'Safety guidelines',
      (t) => _render(
          t, const SafetyGuidelinesScreen(previewOnly: true), 'auth-safety'));

  for (final entry in {
    'front': const OnboardingScreen(),
    'sign in': const LoginScreen(),
    'code': const OtpScreen(phone: '+91 98765 43210'),
    'safety': const SafetyGuidelinesScreen(previewOnly: true),
  }.entries) {
    testWidgets(
        '${entry.key} fits a small phone with large text',
        (t) => _render(t, entry.value, 'x',
            size: const Size(320, 640), textScale: 1.6));
  }
}
