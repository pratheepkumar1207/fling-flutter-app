import 'package:fling/screens/lobby/source_search_area.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Search area: pasted link shows a preview, bad link says so',
      (t) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SourceSearchArea(
            inRoom: false,
            onPick: (
                {required sourceType,
                required videoUrl,
                required title,
                thumbnail}) {},
            sources: const Text('the sources'),
          ),
        ),
      ),
    ));
    await t.pump();
    expect(find.text('the sources'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'https://example.com/x');
    await t.testTextInput.receiveAction(TextInputAction.search);
    await t.pump();
    expect(find.textContaining('can’t play here'), findsOneWidget);
    expect(find.text('the sources'), findsNothing);
    await t.enterText(find.byType(TextField),
        'https://drive.google.com/file/d/abcdefghijkl/view');
    await t.testTextInput.receiveAction(TextInputAction.search);
    await t.pump();
    expect(find.text('Start watching'), findsOneWidget);
  });
}
