import 'package:fling/widgets/insync_attach_sheet.dart';
import 'package:fling/widgets/view_once.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _img =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

Widget _host(Widget Function(BuildContext) button) => MaterialApp(
      home: Builder(builder: (context) => Scaffold(body: button(context))),
    );

void main() {
  testWidgets('View-once viewer counts down and closes itself', (tester) async {
    await tester.pumpWidget(_host((context) => TextButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const ViewOnceViewer(
                  mediaUrl: _img, title: 'Divya\'s photo'))),
          child: const Text('open'),
        )));
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Divya\'s photo'), findsOneWidget);
    expect(find.text('Closes in 10 seconds'), findsOneWidget);
    expect(find.text('Can’t screenshot, save or forward'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 3600));
    expect(find.text('Closes in 6 seconds'), findsOneWidget);
    await tester.pump(const Duration(seconds: 7));
    await tester.pumpAndSettle();
    expect(find.byType(ViewOnceViewer), findsNothing);
  });

  testWidgets('View-once card says what each side can do', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(children: [
          ViewOnceCard(mine: false, onOpen: () => taps++),
          const ViewOnceCard(mine: true),
        ]),
      ),
    ));
    expect(find.text('Tap to open · 10 sec'), findsOneWidget);
    expect(find.text('Sent · not seen yet'), findsOneWidget);
    await tester.tap(find.text('Tap to open · 10 sec'));
    expect(taps, 1);
  });

  testWidgets('Seen photo blows away and leaves a note', (tester) async {
    Widget at(bool gone) => MaterialApp(
          home: Scaffold(
            body: Center(
              child: VanishOnce(
                gone: gone,
                after: const ViewOnceGoneNote('Photo viewed and removed'),
                child: const SizedBox(
                    width: 200, height: 50, child: Text('the card')),
              ),
            ),
          ),
        );
    await tester.pumpWidget(at(false));
    expect(find.text('the card'), findsOneWidget);
    await tester.pumpWidget(at(true));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('the card'), findsNothing); // turning to dust
    expect(find.text('Photo viewed and removed'), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('Photo viewed and removed'), findsOneWidget);

    // Already seen when it first shows: just the note.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(at(true));
    expect(find.text('Photo viewed and removed'), findsOneWidget);
  });

  test('gone note labels', () {
    expect(
        ViewOnceGoneNote.label(
            mine: true, name: 'Divya', at: DateTime(2026, 10, 29, 16, 12)),
        'Divya viewed your photo · 4:12 PM');
    expect(ViewOnceGoneNote.label(mine: false), 'Photo viewed and removed');
  });

  testWidgets('Attach sheet shows only the options asked for', (tester) async {
    AttachKind? picked;
    await tester.pumpWidget(_host((context) => TextButton(
          onPressed: () async => picked = await showInsyncAttachSheet(context,
              options: const [AttachKind.gallery, AttachKind.camera]),
          child: const Text('attach'),
        )));
    await tester.tap(find.text('attach'));
    await tester.pumpAndSettle();
    expect(find.text('Gallery'), findsOneWidget);
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('Document'), findsNothing);
    await tester.tap(find.text('Camera'));
    await tester.pumpAndSettle();
    expect(picked, AttachKind.camera);
  });

  testWidgets('Photo preview sends with the View once switch', (tester) async {
    bool? result;
    await tester.pumpWidget(_host((context) => TextButton(
          onPressed: () async =>
              result = await showPhotoSendPreview(context, _img),
          child: const Text('pick'),
        )));
    await tester.tap(find.text('pick'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View once'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    expect(result, true);
  });
}
