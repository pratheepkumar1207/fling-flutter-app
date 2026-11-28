import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../models/room_models.dart';
import '../../theme/app_colors.dart';
import '../../theme/insync_icons.dart';
import '../../widgets/avatar.dart';
import 'room_socket_controller.dart';

/// The host's requests in a lobby, as cards stacked under the top bar:
/// someone wants the mic (Yes / No, "2 more waiting"), someone asks to join
/// a private lobby (Let in / No). Newest on top; swipe a card away to hide
/// it. Only the host sees this.
class HostRequestTray extends StatefulWidget {
  final RoomSocketController rs;
  const HostRequestTray({super.key, required this.rs});

  @override
  State<HostRequestTray> createState() => _HostRequestTrayState();
}

class _HostRequestTrayState extends State<HostRequestTray> {
  // Hidden by a swipe (the request itself stays in the people list).
  final Set<String> _hiddenMic = {};
  final Set<String> _busy = {};

  RosterEntry? _person(String id) {
    for (final r in widget.rs.roster) {
      if (r.userId == id) return r;
    }
    return null;
  }

  Future<void> _letIn(Map ask) async {
    final id = ask['userId'] as String;
    setState(() => _busy.add(id));
    try {
      await ApiClient.post('/rooms/${widget.rs.roomId}/invite', body: {
        'userIds': [id]
      });
    } catch (_) {}
    widget.rs.dismissJoinAsk(id);
    if (mounted) setState(() => _busy.remove(id));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.rs,
      builder: (context, _) {
        final rs = widget.rs;
        // Mic requests: host and co-hosts. Who gets into a private lobby: host.
        if (!rs.canApproveMics) return const SizedBox.shrink();
        final pending = [
          for (final id in (rs.call['pendingRequests'] as List? ?? const [])
              .cast<String>())
            if (!_hiddenMic.contains(id)) id
        ];
        final asks = rs.isHost ? rs.joinAsks : const <Map<String, dynamic>>[];
        if (pending.isEmpty && asks.isEmpty) return const SizedBox.shrink();
        final cards = <Widget>[
          for (final a in asks.take(2))
            _card(
              key: ValueKey('ask-${a['userId']}'),
              onDismiss: () => rs.dismissJoinAsk(a['userId'] as String),
              avatar: a['avatarUrl'] as String?,
              name: '${a['name'] ?? 'Someone'}',
              icon: InIcons.useradd,
              title: '${a['name'] ?? 'Someone'} asks to join',
              sub: 'Private lobby',
              no: () => rs.dismissJoinAsk(a['userId'] as String),
              yesLabel: 'Let in',
              yesWhite: true,
              busy: _busy.contains(a['userId']),
              yes: () => _letIn(a),
            ),
          if (pending.isNotEmpty)
            Builder(builder: (_) {
              final id = pending.first;
              final p = _person(id);
              final more = pending.length - 1;
              return _card(
                key: ValueKey('mic-$id'),
                onDismiss: () => setState(() => _hiddenMic.add(id)),
                avatar: p?.avatarUrl,
                name: p?.name ?? 'Someone',
                icon: InIcons.mic,
                title:
                    '${(p?.name ?? 'Someone').split(' ').first} wants the mic',
                sub: more > 0 ? '$more more waiting' : 'Raised a hand',
                no: () => rs.denyMic(id),
                yesLabel: 'Yes',
                yesWhite: false,
                busy: false,
                yes: () => rs.approveMic(id),
              );
            }),
        ];
        return Column(mainAxisSize: MainAxisSize.min, children: cards);
      },
    );
  }

  Widget _card({
    required Key key,
    required VoidCallback onDismiss,
    required String? avatar,
    required String name,
    required InIconData icon,
    required String title,
    required String sub,
    required VoidCallback no,
    required String yesLabel,
    required bool yesWhite,
    required bool busy,
    required VoidCallback yes,
  }) {
    return Dismissible(
      key: key,
      onDismissed: (_) => onDismiss(),
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 6),
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary),
        ),
        child: Row(children: [
          SizedBox.square(
            dimension: 34,
            child: FittedBox(
                child: Avatar(src: avatar, name: name, size: AvatarSize.sm)),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [
                    InIcon(icon, size: 14, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                    ),
                  ]),
                  Text(sub,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 11.5)),
                ]),
          ),
          const SizedBox(width: 6),
          _pill('No', onTap: no, filled: false),
          const SizedBox(width: 6),
          _pill(busy ? '…' : yesLabel,
              onTap: busy ? null : yes, filled: true, white: yesWhite),
        ]),
      ),
    );
  }

  Widget _pill(String label,
      {required VoidCallback? onTap,
      required bool filled,
      bool white = false}) {
    final bg =
        !filled ? Colors.black : (white ? Colors.white : AppColors.primary);
    final fg = filled && white ? Colors.black : Colors.white;
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: bg,
        shape: StadiumBorder(
            side: filled
                ? BorderSide.none
                : const BorderSide(color: Colors.white)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Text(label,
                style: TextStyle(
                    color: fg, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }
}
