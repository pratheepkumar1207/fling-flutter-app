import 'package:fling/widgets/swipe_down_to_close.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Pulling a scrolling sheet down from the top closes it',
      (t) async {
    await t.pumpWidget(MaterialApp(
      theme: ThemeData(platform: TargetPlatform.android),
      home: Builder(
        builder: (c) => TextButton(
          onPressed: () => showModalBottomSheet(
            context: c,
            isScrollControlled: true,
            builder: (_) => SwipeDownToClose(
              child: SizedBox(
                height: 400,
                child: SingleChildScrollView(
                  child: Column(children: [
                    for (var i = 0; i < 30; i++)
                      SizedBox(height: 60, child: Text('row $i')),
                  ]),
                ),
              ),
            ),
          ),
          child: const Text('open'),
        ),
      ),
    ));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.text('row 0'), findsOneWidget);

    await t.drag(find.text('row 2'), const Offset(0, -200));
    await t.pumpAndSettle();
    expect(find.text('row 5'), findsOneWidget,
        reason: 'scrolling up keeps it open');

    await t.drag(find.text('row 5'), const Offset(0, 500));
    await t.pumpAndSettle();
    expect(find.text('row 5'), findsNothing);
  });
}
