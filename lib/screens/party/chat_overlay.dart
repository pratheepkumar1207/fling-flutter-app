import 'package:flutter/material.dart';
import '../../core/profile_nav.dart';

// Deterministic per-sender name color, cycling through a small palette —
// matches WatchPartyDark.dc.html's floating chat, where each speaker's name
// is a distinct color instead of a uniform bubble color.
const _nameColors = [
  Color(0xFFDBB155), // gold
  Color(0xFFCC9DE8), // lilac
  Color(0xFF9DE8B8), // mint
  Color(0xFFE89D9D), // rose
  Color(0xFF9DC5E8), // sky
];

/// Floating, translucent chat overlay for Watch Party — meant to sit inside
/// a Stack over the room's "stage" area rather than in a bordered panel like
/// ChatPanel. Deliberately a separate widget (not a ChatPanel variant): the
/// message-bubble styling here (no avatar, no per-message timestamp, name
/// colored inline) is specific to floating-over-content use and would be a
/// bad fit for ChatPanel's other callers (Voice/Game room's chat sheet),
/// where the plain bordered/bubbled look stays untouched.
class ChatOverlay extends StatefulWidget {
  final List<Map<String, dynamic>> messages;
  final void Function(String text) onSend;
  final String? myUserId;
  final Color primaryColor;
  final Color textColor;

  const ChatOverlay({
    super.key,
    required this.messages,
    required this.onSend,
    this.myUserId,
    required this.primaryColor,
    required this.textColor,
  });

  @override
  State<ChatOverlay> createState() => _ChatOverlayState();
}

class _ChatOverlayState extends State<ChatOverlay> {
  final _controller = TextEditingController();

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _controller.clear();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _nameColor(String? senderId) {
    if (senderId == null) return _nameColors[0];
    return _nameColors[senderId.hashCode.abs() % _nameColors.length];
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.messages.where((m) => m['system'] != true).toList().reversed.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: visible.isEmpty
              ? const SizedBox.shrink()
              : ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
                  itemCount: visible.length,
                  itemBuilder: (context, i) {
                    final m = visible[i];
                    final name = m['name'] as String? ?? 'Someone';
                    final senderId = m['senderId'] as String?;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: GestureDetector(
                          onTap: () => openProfile(context, senderId),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 260),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(14)),
                              child: RichText(
                                text: TextSpan(
                                  style: const TextStyle(fontSize: 12.5, color: Colors.white),
                                  children: [
                                    TextSpan(text: '$name  ', style: TextStyle(fontWeight: FontWeight.w700, color: _nameColor(senderId))),
                                    TextSpan(text: m['text'] as String? ?? ''),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 38,
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(100)),
                padding: const EdgeInsets.symmetric(horizontal: 15),
                alignment: Alignment.center,
                child: TextField(
                  controller: _controller,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  onSubmitted: (_) => _send(),
                  decoration: const InputDecoration(
                    hintText: 'Say something…',
                    hintStyle: TextStyle(color: Colors.white54),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _send,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: widget.primaryColor, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: const Icon(Icons.send_rounded, color: Colors.white, size: 17),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
