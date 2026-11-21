import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../widgets/permission_primer.dart';
import 'call_screen.dart';

/// Rings [userId] and opens the call screen as the caller. Used by a chat
/// thread's call buttons and by Chat → Calls.
Future<void> startDirectCall(
  BuildContext context, {
  required String userId,
  required String name,
  String? avatarUrl,
  required bool video,
}) async {
  if (!await checkPermissionsOrExplain(context, camera: video) ||
      !context.mounted) {
    return;
  }
  try {
    final data = await ApiClient.post('/calls/direct-invite',
            body: {'toUserId': userId, 'mode': video ? 'video' : 'audio'})
        as Map<String, dynamic>;
    if (!context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CallScreen(
        channelName: data['channelName'] as String,
        token: data['token'] as String,
        uid: data['uid'] as int,
        video: video,
        isCaller: true,
        peerId: userId,
        peerName: name,
        peerAvatarUrl: avatarUrl,
      ),
    ));
  } on ApiException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}
