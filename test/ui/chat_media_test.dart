import 'package:fling/theme/app_theme.dart';
import 'package:fling/widgets/chat_media.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _png =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

void main() {
  testWidgets('Photo and voice bubbles render and are labelled', (t) async {
    await t.pumpWidget(MaterialApp(
      theme: AppTheme.darkWithoutWebFonts(),
      home: Scaffold(
        body: Column(children: [
          const ChatPhoto(_png),
          const ChatPhoto('data:image/png;base64,not-base64!'),
          const ChatVoiceNote('data:audio/mp4;base64,AAAA'),
          VoiceRecordButton(onRecorded: (_) {}),
        ]),
      ),
    ));
    await t.pump();
    expect(t.takeException(), isNull);
    expect(find.bySemanticsLabel('Photo, tap to open'), findsOneWidget);
    expect(find.text('Photo unavailable'), findsOneWidget);
    expect(find.bySemanticsLabel('Play voice message'), findsOneWidget);
    expect(find.bySemanticsLabel('Hold to record a voice message'),
        findsOneWidget);
  });
}
