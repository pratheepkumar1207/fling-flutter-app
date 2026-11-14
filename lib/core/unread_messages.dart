import 'package:flutter/foundation.dart';

import 'api_client.dart';

/// Total unread across conversations and groups, for the Chat tab's badge.
/// Refreshed on new DMs/group messages (see AppShell) and when Chat closes.
class UnreadMessages {
  UnreadMessages._();

  static final count = ValueNotifier<int>(0);

  static Future<void> refresh() async {
    try {
      final results = await Future.wait([
        ApiClient.get('/messages/conversations'),
        ApiClient.get('/groups').catchError((_) => <dynamic>[]),
      ]);
      var total = 0;
      for (final list in results) {
        if (list is! List) continue;
        for (final c in list) {
          if (c is Map) total += (c['unreadCount'] as num?)?.toInt() ?? 0;
        }
      }
      count.value = total;
    } catch (_) {
      // Badge is best-effort.
    }
  }
}
