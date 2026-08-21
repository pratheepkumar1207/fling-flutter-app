import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/api_client.dart';
import '../core/auth_provider.dart';
import '../core/format.dart';
import '../theme/app_colors.dart';
import 'app_image.dart';
import 'avatar.dart';
import 'story_bar.dart';

/// Full-screen tap-through story viewer — Dart port of StoryViewer.jsx.
/// Auto-advances through the current user's items on a timer, tap left/
/// right thirds of the screen to go back/forward, swipe left/right (via
/// PageView) to move between people.
class StoryViewerScreen extends StatefulWidget {
  final List<StoryEntry> groups;
  final int startGroupIndex;

  const StoryViewerScreen(
      {super.key, required this.groups, required this.startGroupIndex});

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen>
    with SingleTickerProviderStateMixin {
  late int _groupIndex;
  int _itemIndex = 0;
  late AnimationController _controller;
  final _replyController = TextEditingController();
  final _replyFocus = FocusNode();
  bool _replying = false;
  bool _sending = false;

  static const _defaultDuration = Duration(seconds: 5);
  static const _mediaDuration = Duration(seconds: 8);

  StoryEntry get _group => widget.groups[_groupIndex];
  StoryItem get _item => _group.items[_itemIndex];

  @override
  void initState() {
    super.initState();
    _groupIndex = widget.startGroupIndex;
    _controller = AnimationController(vsync: this);
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) _goNext();
    });
    _replyFocus.addListener(() {
      if (!_replyFocus.hasFocus && _replying) _stopReplying();
    });
    _startTimer();
  }

  void _startTimer() {
    final duration = (_item.mediaType == 'voice' || _item.mediaType == 'reel')
        ? _mediaDuration
        : _defaultDuration;
    _controller
      ..duration = duration
      ..forward(from: 0);
  }

  void _goNext() {
    if (_itemIndex < _group.items.length - 1) {
      setState(() => _itemIndex++);
      _startTimer();
    } else if (_groupIndex < widget.groups.length - 1) {
      setState(() {
        _groupIndex++;
        _itemIndex = 0;
      });
      _startTimer();
    } else {
      Navigator.of(context).pop();
    }
  }

  void _goPrev() {
    if (_itemIndex > 0) {
      setState(() => _itemIndex--);
      _startTimer();
    } else if (_groupIndex > 0) {
      setState(() {
        _groupIndex--;
        _itemIndex = widget.groups[_groupIndex].items.length - 1;
      });
      _startTimer();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _replyController.dispose();
    _replyFocus.dispose();
    super.dispose();
  }

  void _startReplying() {
    _controller.stop();
    setState(() => _replying = true);
    _replyFocus.requestFocus();
  }

  void _stopReplying() {
    setState(() => _replying = false);
    _replyFocus.unfocus();
    _controller.forward();
  }

  Future<void> _sendReply(String text) async {
    if (text.trim().isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ApiClient.post('/messages/${_group.userId}',
          body: {'text': text.trim()});
      if (!mounted) return;
      _replyController.clear();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Reply sent')));
      _stopReplying();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to send reply')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final group = _group;
    final item = _item;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: GestureDetector(
          onTapUp: (details) {
            if (_replying) return;
            final width = MediaQuery.of(context).size.width;
            if (details.localPosition.dx < width * 0.3) {
              _goPrev();
            } else {
              _goNext();
            }
          },
          child: Stack(
            children: [
              Positioned.fill(child: _buildMedia(item)),
              Positioned(
                top: 8,
                left: 8,
                right: 8,
                child: Row(
                  children: List.generate(group.items.length, (i) {
                    return Expanded(
                      child: Container(
                        height: 2,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(2)),
                        child: AnimatedBuilder(
                          animation: _controller,
                          builder: (context, _) {
                            final fraction = i < _itemIndex
                                ? 1.0
                                : (i == _itemIndex ? _controller.value : 0.0);
                            return FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: fraction,
                              child: Container(
                                  decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(2))),
                            );
                          },
                        ),
                      ),
                    );
                  }),
                ),
              ),
              Positioned(
                top: 20,
                left: 12,
                right: 12,
                child: Row(
                  children: [
                    Avatar(
                        src: group.avatarUrl,
                        name: group.name,
                        size: AvatarSize.sm),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(group.name ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13)),
                          Text(formatRelativeTime(item.createdAt),
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 11)),
                        ],
                      ),
                    ),
                    IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white)),
                  ],
                ),
              ),
              if (group.userId != context.watch<AuthProvider>().user?.id)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 22 + MediaQuery.of(context).viewInsets.bottom,
                  child: _replyBar(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _replyBar() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3), width: 1.5),
            ),
            alignment: Alignment.centerLeft,
            child: TextField(
              controller: _replyController,
              focusNode: _replyFocus,
              onTap: _startReplying,
              onSubmitted: _sendReply,
              textInputAction: TextInputAction.send,
              style: const TextStyle(color: Colors.white, fontSize: 12.5),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: 'Send a message',
                hintStyle: TextStyle(color: Colors.white70, fontSize: 12.5),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () => _sendReply('❤️'),
          child: const Icon(Icons.favorite_border_rounded,
              color: Colors.white, size: 24),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () => _sendReply(_replyController.text),
          child: _sending
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.send_rounded, color: Colors.white, size: 22),
        ),
      ],
    );
  }

  Widget _buildMedia(StoryItem item) {
    if (item.mediaType == 'image' && item.imageData != null) {
      return Center(
          child: AppImage(source: item.imageData, fit: BoxFit.contain));
    }
    if (item.mediaType == 'reel' && item.videoData != null) {
      return const Center(child: Text('🎥', style: TextStyle(fontSize: 64)));
    }
    if (item.mediaType == 'voice') {
      return Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎵', style: TextStyle(fontSize: 64)),
            if (item.text != null) ...[
              const SizedBox(height: 16),
              Text(item.text!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600)),
            ],
          ],
        ),
      );
    }
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: const BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: AppGradients.brand)),
      child: Text(item.text ?? '',
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
    );
  }
}
