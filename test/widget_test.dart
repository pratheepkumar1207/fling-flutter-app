// Basic smoke test — confirms the app boots to the splash screen without
// throwing. Auth/network calls aren't mocked here, so this intentionally
// only checks that InsyncApp builds, not that login/data-loading succeeds.

import 'package:flutter_test/flutter_test.dart';

import 'package:insync/main.dart';

void main() {
  testWidgets('InsyncApp builds without throwing', (WidgetTester tester) async {
    await tester.pumpWidget(const InsyncApp());
    expect(find.bySemanticsLabel('Insync'), findsWidgets);
  });
}
