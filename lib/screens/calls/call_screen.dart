import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../core/agora_lens_bridge.dart';
import '../../core/api_client.dart';
import '../../core/snap_lens_engine.dart';
import '../../core/call_ring.dart';
import '../../core/socket_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/insync_icons.dart';
import '../../widgets/avatar.dart';
import '../../widgets/gift_bottom_sheet.dart';
import '../../widgets/snap_lens_row.dart';
import 'direct_call_controller.dart';
import '../../widgets/insync_snack.dart';

/// Full-screen 1:1 call UI — audio or video, direct (not room-scoped).
/// Matches AudioCallDark.dc.html / VideoCallDark.dc.html: translucent
/// circle buttons on a soft gradient background, a centered "Calling…"
/// avatar for audio, and for video a top status bar (name + live duration)
/// with a camera-flip button plus a gift button alongside mic/camera/
/// speaker/end-call. See calls.js's direct-invite/accept/decline/cancel/
/// end and DirectCallController for the Agora side. [isCaller] only
/// changes the "Calling…" copy shown before the other side's video/audio
/// actually joins the channel (see DirectCallController.remoteUid) — both
/// sides already have a live token by the time this screen opens (caller
/// gets one from direct-invite, callee from direct-accept), so there's no
/// separate "waiting for my own token" state to render.
class CallScreen extends StatefulWidget {
  final String channelName;
  final String token;
  final int uid;
  final bool video;
  final bool isCaller;
  final String peerId;
  final String peerName;
  final String? peerAvatarUrl;

  const CallScreen({
    super.key,
    required this.channelName,
    required this.token,
    required this.uid,
    required this.video,
    required this.isCaller,
    required this.peerId,
    required this.peerName,
    this.peerAvatarUrl,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  late final DirectCallController _controller;
  String? _endReason;
  Timer? _durationTimer;
  // Its own notifier, so the clock doesn't rebuild the video every second.
  final _elapsed = ValueNotifier(Duration.zero);
  bool _wasConnected = false;
  bool _controlsVisible = true;
  Timer? _hideControlsTimer;
  Timer? _noAnswerTimer;
  Timer? _peerGoneTimer;
  Widget? _remoteView;
  int? _remoteViewUid;
  Widget? _localView;

  // Snap lenses in video calls: the yellow button opens a lens row; the
  // other person sees the lens (AgoraLensBridge).
  bool _lensesOk = false;
  bool _lensRow = false;
  AgoraLensBridge? _lens;
  bool _frontCamera = true;

  AgoraLensBridge? get _bridge {
    final engine = _controller.engine;
    if (_lens == null && engine != null) {
      _lens = AgoraLensBridge(engine)
        ..addListener(() {
          if (mounted) setState(() {});
        });
    }
    return _lens;
  }

  Future<void> _toggleLensRow() async {
    final b = _bridge;
    if (b == null) return;
    setState(() => _lensRow = !_lensRow);
    if (_lensRow) {
      _hideControlsTimer?.cancel();
      try {
        await b.loadLenses();
      } catch (_) {}
    } else {
      _showControls();
    }
  }

  Future<void> _chooseLens(SnapLens? lens) async {
    final b = _bridge;
    if (b == null) return;
    try {
      await b.choose(lens, front: _frontCamera);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(insyncSnackBar(
            content: Text('That lens couldn’t start. Try another.')));
      }
    }
  }

  Future<void> _flipCamera() async {
    _frontCamera = !_frontCamera;
    final b = _lens;
    if (b != null && b.active) {
      await b.flip();
    } else {
      await _controller.switchCamera();
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = DirectCallController(
        channelName: widget.channelName,
        token: widget.token,
        uid: widget.uid,
        video: widget.video);
    _controller.addListener(_onControllerChanged);
    if (widget.isCaller) {
      CallRing.ringback();
      _noAnswerTimer = Timer(const Duration(seconds: 45), () {
        if (!mounted || _controller.remoteUid != null) return;
        CallRing.stop();
        setState(() => _endReason = 'No answer');
        Future.delayed(const Duration(milliseconds: 900), () {
          if (mounted) _hangUp();
        });
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _bindSocket());
    if (widget.video) {
      SnapLensEngine.instance.supported().then((ok) {
        if (ok && mounted) setState(() => _lensesOk = true);
      });
    }
  }

  void _onControllerChanged() {
    final connected = _controller.remoteUid != null;
    if (connected && !_wasConnected) {
      _wasConnected = true;
      _durationTimer?.cancel();
      _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        _elapsed.value += const Duration(seconds: 1);
      });
      CallRing.stop();
      _noAnswerTimer?.cancel();
      _showControls();
    }
    // The other phone dropped out (crash, no signal). Give it a moment to
    // come back, then end the call so it's logged with its real length.
    if (_wasConnected && !connected) {
      _peerGoneTimer ??= Timer(const Duration(seconds: 20), () {
        if (!mounted || _controller.remoteUid != null) return;
        setState(() => _endReason = 'Call ended');
        Future.delayed(const Duration(milliseconds: 900), () {
          if (mounted) _hangUp();
        });
      });
    } else if (connected) {
      _peerGoneTimer?.cancel();
      _peerGoneTimer = null;
    }
  }

  /// In a video call the buttons step aside so the video can be seen; a tap
  /// brings them back.
  void _showControls() {
    _hideControlsTimer?.cancel();
    if (mounted) setState(() => _controlsVisible = true);
    if (!widget.video || _controller.remoteUid == null) return;
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void _toggleControls() {
    if (_controlsVisible) {
      _hideControlsTimer?.cancel();
      setState(() => _controlsVisible = false);
    } else {
      _showControls();
    }
  }

  Widget _durationText(TextStyle style) => ValueListenableBuilder<Duration>(
        valueListenable: _elapsed,
        builder: (_, d, __) => Text(_formatDuration(d), style: style),
      );

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
  }

  io.Socket? _socket;
  final _socketHandlers = <String, dynamic Function(dynamic)>{};

  void _bindSocket() {
    final socket = context.read<SocketService>().socket;
    _socket = socket;
    void onDone(String reason) {
      if (!mounted) return;
      CallRing.stop();
      if (!mounted) return;
      setState(() => _endReason = reason);
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) Navigator.of(context).pop();
      });
    }

    void on(String event, String reason) {
      void handler(dynamic data) {
        if (data is Map && data['channelName'] == widget.channelName) {
          onDone(reason);
        }
      }

      _socketHandlers[event] = handler;
      socket?.on(event, handler);
    }

    on('call:declined', '${widget.peerName} declined');
    on('call:cancelled', 'Call cancelled');
    on('call:ended', 'Call ended');
  }

  Future<void> _hangUp() async {
    CallRing.stop();
    // If I'm the caller and the other side never actually joined media
    // (_controller.remoteUid is still null), this is a cancel — the callee
    // may still be looking at their incoming-call dialog (see
    // app_shell.dart's _showIncomingCall) and needs the distinct
    // call:cancelled event to dismiss it, not call:ended.
    // _wasConnected, not remoteUid: after the other side drops out mid-call
    // remoteUid is null again, but that's an end, not a cancel.
    final neverConnected = widget.isCaller && !_wasConnected;
    final endpoint =
        neverConnected ? '/calls/direct-cancel' : '/calls/direct-end';
    ApiClient.post(endpoint, body: {'channelName': widget.channelName})
        .catchError((_) => null);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _hangUp();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final connected = _controller.remoteUid != null;
              return Stack(
                fit: StackFit.expand,
                children: [
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                          center: Alignment(0, -0.4),
                          radius: 1,
                          colors: [Color(0xFFB81427), AppColors.bg]),
                    ),
                  ),
                  if (widget.video && connected)
                    _remoteVideo()
                  else
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!widget.video)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                _endReason ??
                                    (connected
                                        ? 'Connected'
                                        : (widget.isCaller
                                            ? 'Calling…'
                                            : 'Connecting…')),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppGradients.brandDiagonal,
                              boxShadow: [
                                BoxShadow(
                                    color: AppColors.purple
                                        .withValues(alpha: 0.18),
                                    spreadRadius: 14),
                              ],
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                  color: AppColors.bg, shape: BoxShape.circle),
                              child: SizedBox(
                                width: 124,
                                height: 124,
                                child: FittedBox(
                                  child: Avatar(
                                      src: widget.peerAvatarUrl,
                                      name: widget.peerName,
                                      size: AvatarSize.lg),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const SizedBox(height: 16),
                          Text(widget.peerName,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold)),
                          if (!widget.video) ...[
                            const SizedBox(height: 4),
                            if (connected)
                              _durationText(const TextStyle(
                                  color: Colors.white, fontSize: 14))
                            else
                              const Text('Audio call',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 12.5)),
                          ] else
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                _endReason ??
                                    (widget.isCaller
                                        ? 'Calling…'
                                        : 'Connecting…'),
                                style: const TextStyle(
                                    color: AppColors.textFaint, fontSize: 14),
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (widget.video && connected)
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _toggleControls,
                      ),
                    ),
                  if (widget.video &&
                      _controller.joined &&
                      _controller.cameraEnabled)
                    Positioned(
                      top: 70,
                      right: 16,
                      width: 96,
                      height: 136,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: _lens?.textureId != null
                            ? Texture(textureId: _lens!.textureId!)
                            : _localView ??= AgoraVideoView(
                                controller: VideoViewController(
                                    rtcEngine: _controller.engine!,
                                    canvas: const VideoCanvas(uid: 0))),
                      ),
                    ),
                  if (widget.video)
                    Positioned(
                      top: 18,
                      left: 20,
                      right: 20,
                      child: _fading(Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(widget.peerName,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15)),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    if (connected)
                                      Container(
                                          width: 6,
                                          height: 6,
                                          margin:
                                              const EdgeInsets.only(right: 5),
                                          decoration: const BoxDecoration(
                                              color: AppColors.success,
                                              shape: BoxShape.circle)),
                                    if (connected)
                                      _durationText(const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11.5))
                                    else
                                      Text(
                                        _endReason ??
                                            (widget.isCaller
                                                ? 'Calling…'
                                                : 'Connecting…'),
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11.5),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: _flipCamera,
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.black),
                              alignment: Alignment.center,
                              child: const InIcon(InIcons.flip,
                                  size: 16, color: Colors.white),
                            ),
                          ),
                        ],
                      )),
                    ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 24,
                    child: _fading(
                        Column(mainAxisSize: MainAxisSize.min, children: [
                      if (_lensRow && _lens != null) ...[
                        SnapLensStrip(
                          lenses: _lens!.lenses,
                          selected: _lens!.lens,
                          onChanged: _chooseLens,
                          onMore: () async {
                            final r =
                                await showSnapLensPicker(context, _lens!.lens);
                            if (r.picked) await _chooseLens(r.lens);
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 4, bottom: 10),
                          child: Text('${widget.peerName} sees your lens',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 11)),
                        ),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xE6000000),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Wrap(
                          alignment: WrapAlignment.spaceEvenly,
                          runSpacing: 14,
                          children: [
                            _control(
                                icon: InIcons.speaker,
                                label: 'Speaker',
                                active: _controller.speakerEnabled,
                                onTap: _controller.toggleSpeaker),
                            _control(
                                icon: _controller.micEnabled
                                    ? InIcons.mic
                                    : InIcons.micoff,
                                label:
                                    _controller.micEnabled ? 'Mute' : 'Unmute',
                                active: !_controller.micEnabled,
                                onTap: _controller.toggleMic),
                            if (widget.video) ...[
                              _control(
                                  icon: InIcons.video,
                                  label: _controller.cameraEnabled
                                      ? 'Video'
                                      : 'Video off',
                                  active: !_controller.cameraEnabled,
                                  onTap: _controller.toggleCamera),
                              _control(
                                  icon: InIcons.flip,
                                  label: 'Flip',
                                  onTap: _flipCamera),
                              if (_lensesOk)
                                _control(
                                    icon: InIcons.spark,
                                    label: 'Lenses',
                                    active: _lensRow,
                                    color: Colors.black,
                                    tile: const Color(0xFFFFFC00),
                                    onTap: _toggleLensRow),
                            ],
                            _control(
                                icon: InIcons.gift,
                                label: 'Gift',
                                color: AppColors.gold,
                                tile: const Color(0xFF2A2310),
                                onTap: () => showGiftBottomSheet(context,
                                    toUserId: widget.peerId)),
                            _control(
                                icon: InIcons.phoneoff,
                                label: 'End',
                                color: Colors.white,
                                tile: AppColors.danger,
                                onTap: _hangUp),
                          ],
                        ),
                      ),
                    ])),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _fading(Widget child) => IgnorePointer(
        ignoring: !_controlsVisible,
        child: AnimatedOpacity(
          opacity: _controlsVisible ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: child,
        ),
      );

  Widget _remoteVideo() {
    // Kept between builds, so hiding the buttons doesn't restart the video.
    if (_remoteView == null || _remoteViewUid != _controller.remoteUid) {
      _remoteViewUid = _controller.remoteUid;
      _remoteView = AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: _controller.engine!,
          canvas: VideoCanvas(uid: _controller.remoteUid),
          connection: RtcConnection(channelId: widget.channelName),
        ),
      );
    }
    return _remoteView!;
  }

  Widget _control(
      {required InIconData icon,
      required String label,
      required VoidCallback onTap,
      bool active = false,
      Color color = Colors.white,
      Color? tile}) {
    return SizedBox(
      width: 72,
      child: Semantics(
        button: true,
        toggled: active,
        label: label,
        child: InkResponse(
          onTap: onTap,
          radius: 34,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    tile ?? (active ? Colors.white : const Color(0xFF000000)),
              ),
              alignment: Alignment.center,
              child: InIcon(icon,
                  size: 24,
                  color: tile == null && active ? AppColors.bg : color),
            ),
            const SizedBox(height: 6),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
          ]),
        ),
      ),
    );
  }

  @override
  void dispose() {
    CallRing.stop();
    CallRing.callFinished();
    _durationTimer?.cancel();
    _hideControlsTimer?.cancel();
    _noAnswerTimer?.cancel();
    _peerGoneTimer?.cancel();
    _socketHandlers.forEach((event, handler) => _socket?.off(event, handler));
    _elapsed.dispose();
    _controller.removeListener(_onControllerChanged);
    _lens?.shutdown();
    _lens?.dispose();
    _controller.dispose();
    super.dispose();
  }
}
