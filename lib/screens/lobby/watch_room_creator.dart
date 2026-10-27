import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../party/party_screen.dart';

/// Shared "create the watch-party room, then jump straight into it"
/// step used by both youtube_browse_screen.dart and drive_browse_screen
/// .dart once the user taps a video — this is the Rave-style "pick
/// source, pick content, auto-enter lobby" flow's final step. Clears the
/// whole source-picker screen stack on success (SourcePickerScreen ->
/// YoutubeBrowseScreen/DriveBrowseScreen) so the back button from the
/// party screen returns to wherever the flow started, not back through
/// the picker.
/// What the lobby's create screen collected for a watch room — carried
/// through the source picker so it isn't lost (previously a watch room
/// silently ignored the name and both toggles; only voice rooms used them).
class WatchRoomOptions {
  final String? title;
  final bool micEnabled;

  /// true = the host approves each mic request; false = anyone can hop on.
  final bool hostApprovesMics;
  final bool anyoneCanAddSongs;
  final String? theme;
  const WatchRoomOptions(
      {this.title,
      this.micEnabled = true,
      this.hostApprovesMics = true,
      this.anyoneCanAddSongs = true,
      this.theme});
}

Future<void> createWatchRoomAndEnter(
  BuildContext context, {
  required String sourceType,
  // Nullable for companion-only rooms (Netflix/Prime) — see
  // companion_room_card.dart: there's no embedded player or content URL to
  // store, the room is just a chat/voice space alongside everyone
  // separately watching in their own native app.
  String? videoUrl,
  required String visibility,
  String? topic,
  String? videoTitle,
  String? videoThumbnail,
  WatchRoomOptions? options,
}) async {
  final title = options?.title?.trim();
  try {
    final room = await ApiClient.post('/rooms', body: {
      'roomType': 'watch',
      'sourceType': sourceType,
      if (videoUrl != null) 'videoUrl': videoUrl,
      'visibility': visibility,
      if (topic != null && topic.trim().isNotEmpty) 'topic': topic.trim(),
      if (title != null && title.isNotEmpty) 'title': title,
      if (videoTitle != null) 'videoTitle': videoTitle,
      if (videoThumbnail != null) 'videoThumbnail': videoThumbnail,
    }) as Map<String, dynamic>;
    // Same follow-up the voice-room path does — settings aren't part of
    // POST /rooms. Best-effort: the room still opens if this fails.
    if (options != null) {
      await ApiClient.patch('/rooms/${room['id']}/settings', body: {
        'micEnabled': options.micEnabled,
        'micApproval': options.hostApprovesMics ? 'host' : 'everyone',
        'songPermission': options.anyoneCanAddSongs ? 'anyone' : 'host',
        if (options.theme != null) 'theme': options.theme,
      }).catchError((_) => null);
    }
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
          builder: (_) => PartyScreen(roomId: room['id'] as String)),
      (route) => route.isFirst,
    );
  } on ApiException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}
