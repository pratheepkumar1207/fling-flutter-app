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
}) async {
  try {
    final room = await ApiClient.post('/rooms', body: {
      'roomType': 'watch',
      'sourceType': sourceType,
      if (videoUrl != null) 'videoUrl': videoUrl,
      'visibility': visibility,
      if (topic != null && topic.trim().isNotEmpty) 'topic': topic.trim(),
      if (videoTitle != null) 'videoTitle': videoTitle,
      if (videoThumbnail != null) 'videoThumbnail': videoThumbnail,
    }) as Map<String, dynamic>;
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => PartyScreen(roomId: room['id'] as String)),
      (route) => route.isFirst,
    );
  } on ApiException catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
  }
}
