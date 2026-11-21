import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insync/core/auth_provider.dart';
import 'package:insync/models/user.dart';
import 'package:provider/provider.dart';
import 'package:insync/widgets/story_bar.dart';
import 'package:insync/widgets/story_viewer_screen.dart';

StoryEntry _group(String user, List<String> ids) => StoryEntry(
      userId: user,
      name: user,
      items: [
        for (final id in ids)
          StoryItem(id: id, mediaType: 'text', createdAt: DateTime(2026)),
      ],
    );

class _FakeAuth extends AuthProvider {
  final User _u = User.fromJson({'id': 'me', 'name': 'Test User'});
  @override
  User? get user => _u;
}

void main() {
  testWidgets('only stories that came on screen are reported as shown',
      (tester) async {
    final shown = <String>[];
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: _FakeAuth(),
        child: MaterialApp(
          home: StoryViewerScreen(
            groups: [
              _group('ann', ['a1', 'a2']),
              _group('bob', ['b1']),
              _group('cara', ['c1']),
            ],
            startGroupIndex: 0,
            onItemShown: (i) => shown.add(i.id),
          ),
        )));
    expect(shown, ['a1']);

    // Each text story runs 5 s, then the next one — including the next
    // friend's — comes on screen.
    await tester.pump(const Duration(milliseconds: 5100));
    await tester.pump();
    expect(shown, ['a1', 'a2']);
    await tester.pump(const Duration(milliseconds: 5100));
    await tester.pump();
    expect(shown, ['a1', 'a2', 'b1']);
    expect(shown, isNot(contains('c1')));
  });
}
