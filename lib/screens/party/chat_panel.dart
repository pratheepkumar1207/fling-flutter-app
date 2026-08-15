import 'package:flutter/material.dart';
import '../../core/profile_nav.dart';
import '../../theme/app_colors.dart';
import '../../theme/club_room_colors.dart';
import '../../widgets/avatar.dart';

class ChatPanel extends StatefulWidget {
  final List<Map<String, dynamic>> messages;
  final void Function(String text) onSend;

  /// Voice Room's ClubRoom-matched palette instead of the app's normal
  /// theme — see club_room_colors.dart and party_screen.dart's isVoice.
  final bool clubRoomTheme;

  const ChatPanel({super.key, required this.messages, required this.onSend, this.clubRoomTheme = false});

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void didUpdateWidget(covariant ChatPanel old) {
    super.didUpdateWidget(old);
    if (widget.messages.length != old.messages.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      });
    }
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final club = widget.clubRoomTheme;
    final textFaint = club ? ClubRoomColors.textFaint : AppColors.textFaint;
    final text = club ? ClubRoomColors.text : AppColors.text;
    final textDim = club ? ClubRoomColors.textDim : AppColors.textDim;
    final primary = club ? ClubRoomColors.primary : AppColors.primary;
    return Column(
      children: [
        Expanded(
          child: widget.messages.isEmpty
              ? Center(child: Text('Say hi 👋', style: TextStyle(color: textFaint, fontSize: 12)))
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(10),
                  itemCount: widget.messages.length,
                  itemBuilder: (context, i) {
                    final m = widget.messages[i];
                    final isSystem = m['system'] == true;
                    if (isSystem) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Center(child: Text(m['text'] as String? ?? '', style: TextStyle(color: textFaint, fontSize: 11))),
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () => openProfile(context, m['senderId'] as String?),
                            child: Avatar(src: m['avatarUrl'] as String?, name: m['name'] as String?, size: AvatarSize.sm),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(text: '${m['name'] ?? 'Someone'}  ', style: TextStyle(color: text, fontWeight: FontWeight.w600, fontSize: 12)),
                                  TextSpan(text: m['text'] as String? ?? '', style: TextStyle(color: textDim, fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: TextStyle(color: text, fontSize: 13),
                  decoration: const InputDecoration(hintText: 'Message…', isDense: true),
                  onSubmitted: (_) => _send(),
                ),
              ),
              IconButton(onPressed: _send, icon: Icon(Icons.send, size: 18, color: primary)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
