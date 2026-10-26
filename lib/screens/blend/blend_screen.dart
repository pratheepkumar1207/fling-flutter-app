import '../../theme/insync_icons.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/auth_provider.dart';
import '../../core/socket_service.dart';
import '../../models/blend.dart';
import '../../models/post.dart';
import '../../theme/app_colors.dart';
import '../../widgets/avatar.dart';
import '../../widgets/comments_sheet.dart';
import '../../widgets/reels_feed.dart';
import '../../widgets/spinner.dart';
import '../party/voice_chat_controller.dart';
import 'blend_settings_screen.dart';

const _reactions = ['😂', '🔥', '😍', '😮'];

/// Reels Blend, full screen: the reels everyone in the Blend liked. While
/// others are watching (and the Blend syncs swipes), whoever's allowed to
/// drive moves everyone to the same reel and pauses/plays for all; the
/// rest follow. Reactions and chat float over the reel. With
/// [together], the other members are told you're watching now.
class BlendScreen extends StatefulWidget {
  final String blendId;
  final bool together;
  const BlendScreen({super.key, required this.blendId, this.together = false});

  @override
  State<BlendScreen> createState() => _BlendScreenState();
}

class _Floating {
  final String text;
  final Key key = UniqueKey();
  _Floating(this.text);
}

class _ChatLine {
  final String name;
  final String text;
  final Key key = UniqueKey();
  _ChatLine(this.name, this.text);
}

class _BlendScreenState extends State<BlendScreen> {
  final _pages = PageController();
  final _chatInput = TextEditingController();
  Blend? _blend;
  List<Post> _reels = [];
  Map<String, String> _from = {};
  Map<String, List<String>> _likedBy = {};
  Map<String, int> _mix = {};
  List<String> _sharedIds = [];
  List<Map<String, dynamic>> _watching = [];
  bool _loading = true;
  String? _error;
  int _page = 0;
  bool _paused = false;
  // Set while a move came from someone else, so it isn't sent back out.
  bool _applyingRemote = false;
  String? _activeReelId;
  VideoPlayerController? _player;
  // A position to seek to once that reel's player is ready.
  ({String reelId, double seconds})? _pendingSeek;
  final List<_Floating> _floating = [];
  final List<_ChatLine> _chat = [];
  VoiceChatController? _voice;
  bool _micOn = false;
  dynamic _socket;
  String? _myId;

  @override
  void initState() {
    super.initState();
    _myId = context.read<AuthProvider>().user?.id;
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        ApiClient.get('/blends/${widget.blendId}'),
        ApiClient.get('/blends/${widget.blendId}/reels'),
      ]);
      if (!mounted) return;
      final feed = results[1] as Map<String, dynamic>;
      final reels = <Post>[];
      final from = <String, String>{};
      final likedBy = <String, List<String>>{};
      for (final raw in feed['reels'] as List) {
        final j = Map<String, dynamic>.from(raw as Map);
        final post = Post.fromJson(j);
        reels.add(post);
        if (j['blendFrom'] is String) from[post.id] = j['blendFrom'] as String;
        likedBy[post.id] = [
          for (final id in (j['likedBy'] as List? ?? const [])) id as String
        ];
      }
      setState(() {
        _blend = Blend.fromJson(results[0] as Map<String, dynamic>);
        _reels = reels;
        _from = from;
        _likedBy = likedBy;
        _mix = {
          for (final e in (feed['mix'] as Map? ?? const {}).entries)
            e.key as String: (e.value as num).toInt()
        };
        _sharedIds = [
          for (final id in (feed['sharedIds'] as List? ?? const []))
            id as String
        ];
        _activeReelId ??= reels.isEmpty ? null : reels.first.id;
        _loading = false;
      });
      _bindSocket();
      if (widget.together) {
        ApiClient.post('/blends/${widget.blendId}/watch')
            .catchError((_) => null);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load this Blend';
        });
      }
    }
  }

  Future<void> _reloadBlend() async {
    try {
      final data = await ApiClient.get('/blends/${widget.blendId}');
      if (!mounted) return;
      final next = Blend.fromJson(data as Map<String, dynamic>);
      setState(() => _blend = next);
      if (!next.micEnabled) _stopVoice();
    } catch (_) {}
  }

  // ---- live sync ----

  void _bindSocket() {
    if (_socket != null) return;
    final socket = context.read<SocketService>().socket;
    if (socket == null) return;
    _socket = socket;
    socket.on('connect', _onConnect);
    socket.on('blend:state', _onState);
    socket.on('blend:presence', _onPresence);
    socket.on('blend:react', _onReact);
    socket.on('blend:chat', _onChat);
    socket.on('blend:settings', _onSettings);
    socket.on('blend:removed', _onRemoved);
    _join();
  }

  void _join() => _socket?.emit('blend:join', {'blendId': widget.blendId});
  void _onConnect(dynamic _) => _join();

  bool _mine(dynamic data) => data is Map && data['blendId'] == widget.blendId;

  List<Map<String, dynamic>> get _othersWatching =>
      _watching.where((w) => w['userId'] != _myId).toList();

  // Locked when only the creator drives and they're here driving.
  bool get _locked {
    final b = _blend;
    if (b == null || !b.swipeSync || b.canDrive(_myId)) return false;
    return _watching.any((w) => w['userId'] == b.createdBy);
  }

  bool get _synced =>
      (_blend?.swipeSync ?? false) && _othersWatching.isNotEmpty;

  double get _position =>
      (_player?.value.position.inMilliseconds ?? 0) / 1000.0;

  void _sendState({double? position}) {
    final b = _blend;
    final id = _activeReelId;
    if (b == null || id == null || !b.canDrive(_myId)) return;
    _socket?.emit('blend:state', {
      'blendId': widget.blendId,
      'reelId': id,
      'index': _page,
      'playing': !_paused,
      'position': position ?? _position,
    });
  }

  void _onState(dynamic data) {
    if (!mounted || !_mine(data)) return;
    final reelId = data['reelId'] as String?;
    var index = _reels.indexWhere((r) => r.id == reelId);
    if (index < 0) return;
    final playing = data['playing'] != false;
    final position = (data['position'] as num?)?.toDouble() ?? 0;
    setState(() => _paused = !playing);
    _pendingSeek = (reelId: reelId!, seconds: position);
    if (index != _page && _pages.hasClients) {
      _applyingRemote = true;
      final near = (index - _page).abs() == 1;
      final move = near
          ? _pages.animateToPage(index,
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOut)
          : Future(() => _pages.jumpToPage(index));
      move.whenComplete(() => _applyingRemote = false);
    } else {
      _applySeek();
    }
  }

  void _applySeek() {
    final seek = _pendingSeek;
    final player = _player;
    if (seek == null || player == null || seek.reelId != _activeReelId) return;
    if (!player.value.isInitialized) return;
    _pendingSeek = null;
    final duration = player.value.duration.inMilliseconds / 1000.0;
    var target = seek.seconds;
    if (duration > 0) target = target % duration;
    if ((_position - target).abs() > 1.5) {
      player.seekTo(Duration(milliseconds: (target * 1000).round()));
    }
  }

  void _onPresence(dynamic data) {
    if (!mounted || !_mine(data)) return;
    final before = _othersWatching.map((w) => w['userId']).toSet();
    setState(() => _watching = [
          for (final w in (data['watching'] as List? ?? const []))
            Map<String, dynamic>.from(w as Map)
        ]);
    // Someone new arrived: bring them to where we are.
    if (_othersWatching.any((w) => !before.contains(w['userId']))) _sendState();
  }

  void _onReact(dynamic data) {
    if (!mounted || !_mine(data)) return;
    final f = _Floating(data['emoji'] as String? ?? '❤️');
    setState(() => _floating.add(f));
    Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _floating.remove(f));
    });
  }

  void _onChat(dynamic data) {
    if (!mounted || !_mine(data)) return;
    final mine = data['userId'] == _myId;
    final line = _ChatLine(
        mine ? 'You' : (data['name'] as String? ?? 'Someone'),
        data['text'] as String? ?? '');
    setState(() {
      _chat.add(line);
      if (_chat.length > 4) _chat.removeAt(0);
    });
    Timer(const Duration(seconds: 8), () {
      if (mounted) setState(() => _chat.remove(line));
    });
  }

  void _onSettings(dynamic data) {
    if (_mine(data)) _reloadBlend();
  }

  void _onRemoved(dynamic data) {
    if (!mounted || !_mine(data)) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('This Blend has ended')));
    Navigator.of(context).maybePop();
  }

  // ---- actions ----

  void _onPageChanged(int i) {
    if (i >= _reels.length) return;
    setState(() {
      _page = i;
      _activeReelId = _reels[i].id;
      _player = null;
      if (!_applyingRemote) _paused = false;
    });
    if (!_applyingRemote) _sendState(position: 0);
  }

  void _onPlayer(Post post, VideoPlayerController player) {
    if (post.id != _activeReelId) return;
    _player = player;
    _applySeek();
  }

  void _togglePause() {
    setState(() => _paused = !_paused);
    _sendState();
  }

  void _react(String emoji) =>
      _socket?.emit('blend:react', {'blendId': widget.blendId, 'emoji': emoji});

  void _sendChat() {
    final text = _chatInput.text.trim();
    if (text.isEmpty) return;
    _socket?.emit('blend:chat', {'blendId': widget.blendId, 'text': text});
    _chatInput.clear();
    FocusScope.of(context).unfocus();
  }

  Future<void> _toggleMic() async {
    final voice = _voice ??=
        VoiceChatController(roomId: widget.blendId, tokenPath: '/blends/token');
    await voice.ensureInitialized();
    if (!mounted) return;
    switch (voice.status) {
      case VoiceChatStatus.connected:
        final next = !_micOn;
        await voice.setMicEnabled(next);
        if (mounted) setState(() => _micOn = next);
      case VoiceChatStatus.permissionDenied:
        _snack('Allow microphone access to talk');
      case VoiceChatStatus.failed:
        _snack('Voice isn’t available right now');
      default:
        break;
    }
  }

  void _stopVoice() {
    _voice?.dispose();
    _voice = null;
    if (mounted && _micOn) setState(() => _micOn = false);
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  void _replaceReel(Post next) => setState(() {
        final i = _reels.indexWhere((r) => r.id == next.id);
        if (i != -1) _reels[i] = next;
      });

  Future<void> _like(Post post) async {
    _replaceReel(post.copyWith(
        likedByMe: !post.likedByMe,
        likesCount: post.likesCount + (post.likedByMe ? -1 : 1)));
    try {
      await ApiClient.post('/feed/${post.id}/like');
    } catch (_) {
      _replaceReel(post);
    }
  }

  Future<void> _save(Post post) async {
    _replaceReel(post.copyWith(savedByMe: !post.savedByMe));
    try {
      await ApiClient.post('/feed/${post.id}/save');
    } catch (_) {
      _replaceReel(post);
    }
  }

  void _comments(Post post) => showCommentsSheet(context,
      postId: post.id,
      onCommented: () {},
      commentsDisabled: post.commentsDisabled && !post.isOwn,
      authorName: post.author.name);

  Future<void> _openSettings() async {
    final blend = _blend;
    if (blend == null) return;
    final result = await Navigator.of(context).push<String>(MaterialPageRoute(
      builder: (_) => BlendSettingsScreen(
        blend: blend,
        mix: _mix,
        shared: [
          for (final id in _sharedIds) ..._reels.where((r) => r.id == id),
        ],
      ),
    ));
    if (!mounted) return;
    if (result == 'left') {
      Navigator.of(context).pop();
      return;
    }
    if (result != null) {
      final i = _reels.indexWhere((r) => r.id == result);
      if (i >= 0 && _pages.hasClients) _pages.jumpToPage(i);
    }
    _reloadBlend();
  }

  // ---- UI ----

  Widget? _badge(Post post) {
    final blend = _blend;
    if (blend == null || !blend.showOwnerTag) return null;
    final likers = _likedBy[post.id] ?? const [];
    String label;
    Color color;
    if (likers.length >= 2) {
      label = blend.members.length == 2 && likers.length == 2
          ? 'You both liked'
          : 'Liked by ${likers.length} of you';
      color = AppColors.accent;
    } else {
      final from = _from[post.id];
      label = from == _myId
          ? 'From your likes'
          : 'From ${blend.member(from)?.firstName ?? 'someone'}\'s likes';
      color = blendColorFor(blend, from);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color, width: 1.2)),
      child: Text(label,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w600)),
    );
  }

  Widget _topBar() {
    final blend = _blend!;
    final others = _othersWatching;
    final faces = others.isNotEmpty
        ? others
            .map((w) => (w['avatarUrl'] as String?, w['name'] as String?))
            .toList()
        : blend.others(_myId).map((m) => (m.avatarUrl, m.name)).toList();
    final String status;
    if (others.length == 1) {
      status =
          '${(others.first['name'] as String? ?? 'Someone').split(' ').first} is watching';
    } else if (others.length > 1) {
      status = '${others.length} watching with you';
    } else {
      status = blend.title(_myId);
    }
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).pop(),
              icon: const InIcon(InIcons.down, color: Colors.white, size: 28),
            ),
            SizedBox(
              width: 24.0 + 16 * (faces.take(3).length - 1).clamp(0, 2),
              height: 28,
              child: Stack(children: [
                for (var i = 0; i < faces.take(3).length; i++)
                  Positioned(
                    left: i * 16.0,
                    child: Container(
                      padding: const EdgeInsets.all(1.5),
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: others.isNotEmpty
                              ? AppColors.success
                              : Colors.black),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: FittedBox(
                            child: Avatar(src: faces[i].$1, name: faces[i].$2)),
                      ),
                    ),
                  ),
              ]),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                  Text(
                      others.isEmpty
                          ? 'Only you are here'
                          : _synced
                              ? 'Live · synced'
                              : 'Watching at your own pace',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: others.isNotEmpty && _synced
                              ? AppColors.success
                              : Colors.white70,
                          fontSize: 11.5)),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Blend settings',
              onPressed: _openSettings,
              icon: const InIcon(InIcons.tune, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomBar() {
    final blend = _blend!;
    final canPause = blend.canDrive(_myId) || !_synced;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
        child: Row(
          children: [
            for (final e in _reactions)
              Semantics(
                button: true,
                label: 'React $e',
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _react(e),
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: Text(e, style: const TextStyle(fontSize: 20)),
                  ),
                ),
              ),
            const SizedBox(width: 4),
            Expanded(
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                    border: Border.all(color: Colors.white24),
                    borderRadius: BorderRadius.circular(999)),
                alignment: Alignment.centerLeft,
                child: TextField(
                  controller: _chatInput,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendChat(),
                  // Plain field: the app theme's filled box doesn't fit
                  // inside this pill.
                  decoration: const InputDecoration(
                      isDense: true,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      hintText: 'Say something',
                      hintStyle:
                          TextStyle(color: Colors.white54, fontSize: 13)),
                ),
              ),
            ),
            if (canPause)
              IconButton(
                tooltip: _paused ? 'Play' : 'Pause',
                onPressed: _togglePause,
                icon: InIcon(_paused ? InIcons.play : InIcons.pause,
                    color: Colors.white),
              ),
            if (blend.micEnabled)
              IconButton(
                tooltip: _micOn ? 'Mute mic' : 'Talk',
                onPressed: _toggleMic,
                icon: InIcon(_micOn ? InIcons.mic : InIcons.micoff,
                    color: _micOn ? AppColors.success : Colors.white),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
          backgroundColor: Colors.black, body: Center(child: Spinner()));
    }
    if (_blend == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black),
        body: Center(
            child: Text(_error ?? 'This Blend isn’t available',
                style: const TextStyle(color: AppColors.textFaint))),
      );
    }
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          _topBar(),
          Expanded(
            child: Stack(
              children: [
                ReelsFeed(
                  reels: _reels,
                  controller: _pages,
                  onPageChanged: _onPageChanged,
                  physics:
                      _locked ? const NeverScrollableScrollPhysics() : null,
                  badgeFor: _badge,
                  paused: _paused,
                  onPlayer: _onPlayer,
                  onLike: _like,
                  onSave: _save,
                  onOpenComments: _comments,
                  emptyText:
                      'No liked reels yet.\nLike some reels and they’ll show up here for everyone in this Blend.',
                ),
                if (_locked)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(999)),
                      child: Text(
                          '${_blend!.creator?.firstName ?? 'The host'} is swiping',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 11)),
                    ),
                  ),
                // Chat lines float bottom-left, clear of the right rail.
                Positioned(
                  left: 12,
                  right: 80,
                  bottom: 130,
                  child: IgnorePointer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final c in _chat)
                          Container(
                            key: c.key,
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(12)),
                            child: Text.rich(
                              TextSpan(children: [
                                TextSpan(
                                    text: '${c.name}  ',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700)),
                                TextSpan(text: c.text),
                              ]),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12.5),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // Reactions drift up from the bottom right.
                for (final f in _floating)
                  Positioned(
                    key: f.key,
                    right: 70,
                    bottom: 120,
                    child: IgnorePointer(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 1700),
                        builder: (context, t, child) => Transform.translate(
                          offset: Offset(0, -160 * t),
                          child: Opacity(
                              opacity: t < 0.75 ? 1 : (1 - t) * 4,
                              child: child),
                        ),
                        child:
                            Text(f.text, style: const TextStyle(fontSize: 34)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _bottomBar(),
        ],
      ),
    );
  }

  @override
  void dispose() {
    final s = _socket;
    if (s != null) {
      s.emit('blend:leave', {'blendId': widget.blendId});
      s.off('connect', _onConnect);
      s.off('blend:state', _onState);
      s.off('blend:presence', _onPresence);
      s.off('blend:react', _onReact);
      s.off('blend:chat', _onChat);
      s.off('blend:settings', _onSettings);
      s.off('blend:removed', _onRemoved);
    }
    _voice?.dispose();
    _pages.dispose();
    _chatInput.dispose();
    super.dispose();
  }
}
