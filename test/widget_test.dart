// Basic smoke test — confirms the app boots to the splash screen without
// throwing. Auth/network calls aren't mocked here, so this intentionally
// only checks that FlingApp builds, not that login/data-loading succeeds.

import 'package:flutter_test/flutter_test.dart';

import 'package:fling/main.dart';

void main() {
  testWidgets('FlingApp builds without throwing', (WidgetTester tester) async {
    await tester.pumpWidget(const FlingApp());
    expect(find.text('Fling'), findsWidgets);
  });
}
