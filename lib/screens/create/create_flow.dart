import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import '../../core/api_client.dart';
import '../../core/video_edit.dart';
import '../../theme/app_colors.dart';
import '../../theme/insync_icons.dart';
import '../../widgets/in_icon_button.dart';
import '../../widgets/mention_text_field.dart';
import '../../widgets/people_picker_sheet.dart';
import '../../widgets/permission_primer.dart';

enum CreateMode { post, story, reel }

/// Camera first, as on Instagram: record or pick, then edit, then caption.
Future<void> openCreateFlow(BuildContext context,
    {CreateMode mode = CreateMode.reel, VoidCallback? onPosted}) {
  return Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => CreateCameraScreen(mode: mode, onPosted: onPosted)));
}

class CreateCameraScreen extends StatefulWidget {
  final CreateMode mode;
  final VoidCallback? onPosted;
  const CreateCameraScreen({super.key, required this.mode, this.onPosted});

  @override
  State<CreateCameraScreen> createState() => _CreateCameraScreenState();
}

class _CreateCameraScreenState extends State<CreateCameraScreen> {
  CameraController? _camera;
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;
  late CreateMode _mode = widget.mode;
  int _filter = 0;
  bool _flash = false;
  bool _recording = false;
  bool _noCamera = false;
  int _seconds = 0;
  Timer? _ticker;

  MediaFilter get _look => MediaFilter.colour[_filter];

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final ok = await checkPermissionsOrExplain(context, camera: true);
    if (!ok || !mounted) {
      if (mounted) setState(() => _noCamera = true);
      return;
    }
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) throw StateError('none');
      await _openCamera();
    } catch (_) {
      if (mounted) setState(() => _noCamera = true);
    }
  }

  Future<void> _openCamera() async {
    final previous = _camera;
    final next = CameraController(_cameras[_cameraIndex], ResolutionPreset.high,
        enableAudio: true);
    await next.initialize();
    await previous?.dispose();
    if (!mounted) {
      await next.dispose();
      return;
    }
    setState(() => _camera = next);
  }

  void _flip() {
    if (_cameras.length < 2 || _recording) return;
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    _openCamera();
  }

  Future<void> _toggleFlash() async {
    final c = _camera;
    if (c == null) return;
    _flash = !_flash;
    await c.setFlashMode(_flash ? FlashMode.torch : FlashMode.off);
    if (mounted) setState(() {});
  }

  Future<void> _shutter() async {
    final c = _camera;
    if (c == null) return;
    if (_mode != CreateMode.reel) {
      final shot = await c.takePicture();
      if (mounted) _edit(shot.path, isVideo: false);
      return;
    }
    if (_recording) {
      await _stop();
      return;
    }
    await c.startVideoRecording();
    setState(() {
      _recording = true;
      _seconds = 0;
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _seconds++);
      if (_seconds >= VideoEdit.maxClip.inSeconds) _stop();
    });
  }

  Future<void> _stop() async {
    _ticker?.cancel();
    final c = _camera;
    if (c == null || !_recording) return;
    final clip = await c.stopVideoRecording();
    if (!mounted) return;
    setState(() => _recording = false);
    _edit(clip.path, isVideo: true);
  }

  Future<void> _gallery() async {
    final picker = ImagePicker();
    final file = _mode == CreateMode.reel
        ? await picker.pickVideo(source: ImageSource.gallery)
        : await picker.pickImage(source: ImageSource.gallery);
    if (file == null || !mounted) return;
    _edit(file.path, isVideo: _mode == CreateMode.reel);
  }

  void _edit(String path, {required bool isVideo}) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CreateEditScreen(
              path: path,
              isVideo: isVideo,
              mode: _mode,
              initialFilter: _look,
              onPosted: widget.onPosted,
            )));
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _camera?.dispose();
    super.dispose();
  }

  void _nextFilter(int by) => setState(() =>
      _filter = (_filter + by).clamp(0, MediaFilter.colour.length - 1).toInt());

  @override
  Widget build(BuildContext context) {
    final c = _camera;
    final preview = _look.preview;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(fit: StackFit.expand, children: [
        if (c != null && c.value.isInitialized)
          GestureDetector(
            onHorizontalDragEnd: (d) {
              final v = d.primaryVelocity ?? 0;
              if (v < -200) _nextFilter(1);
              if (v > 200) _nextFilter(-1);
            },
            child: Center(
              child: preview == null
                  ? CameraPreview(c)
                  : ColorFiltered(
                      colorFilter: preview, child: CameraPreview(c)),
            ),
          )
        else if (_noCamera)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                  'Allow the camera to record here, or pick from your gallery.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70)),
            ),
          ),
        SafeArea(
          child: Column(children: [
            Row(children: [
              InIconButton(InIcons.close,
                  tooltip: 'Close',
                  color: Colors.white,
                  onPressed: () => Navigator.of(context).maybePop()),
              const Spacer(),
              if (_recording)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: const Color(0xFFE0364F),
                      borderRadius: BorderRadius.circular(12)),
                  child: Text('0:${_seconds.toString().padLeft(2, '0')}',
                      style: const TextStyle(color: Colors.white)),
                ),
              const Spacer(),
              IconButton(
                tooltip: _flash ? 'Flash off' : 'Flash on',
                onPressed: _toggleFlash,
                icon: Icon(
                    _flash ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                    color: Colors.white),
              ),
              IconButton(
                tooltip: 'Flip camera',
                onPressed: _flip,
                icon:
                    const Icon(Icons.cameraswitch_rounded, color: Colors.white),
              ),
            ]),
            const Spacer(),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (var i = 0; i < MediaFilter.colour.length; i++)
                    _FilterChip(
                      label: MediaFilter.colour[i].name,
                      selected: i == _filter,
                      onTap: () => setState(() => _filter = i),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              IconButton(
                tooltip: 'Choose from gallery',
                iconSize: 32,
                onPressed: _recording ? null : _gallery,
                icon: const Icon(Icons.photo_library_rounded,
                    color: Colors.white),
              ),
              Semantics(
                button: true,
                label: _mode != CreateMode.reel
                    ? 'Take photo'
                    : _recording
                        ? 'Stop recording'
                        : 'Record',
                child: GestureDetector(
                  onTap: _shutter,
                  child: Container(
                    width: 74,
                    height: 74,
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4)),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: _mode == CreateMode.reel
                            ? const Color(0xFFE0364F)
                            : Colors.white,
                        borderRadius:
                            BorderRadius.circular(_recording ? 8 : 40),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ]),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (final m in CreateMode.values)
                TextButton(
                  onPressed:
                      _recording ? null : () => setState(() => _mode = m),
                  child: Text(
                      switch (m) {
                        CreateMode.post => 'Post',
                        CreateMode.story => 'Story',
                        CreateMode.reel => 'Reel',
                      },
                      style: TextStyle(
                          color: m == _mode ? AppColors.lilac : Colors.white70,
                          fontWeight:
                              m == _mode ? FontWeight.w700 : FontWeight.w400)),
                ),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: selected ? AppColors.lilac : Colors.black54,
                borderRadius: BorderRadius.circular(20)),
            child: Text(label,
                style: TextStyle(
                    color: selected ? const Color(0xFF241338) : Colors.white,
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400)),
          ),
        ),
      );
}

/// Step 2: trim, filter (including Cartoon) and sound.
class CreateEditScreen extends StatefulWidget {
  final String path;
  final bool isVideo;
  final CreateMode mode;
  final MediaFilter initialFilter;
  final VoidCallback? onPosted;
  const CreateEditScreen({
    super.key,
    required this.path,
    required this.isVideo,
    required this.mode,
    this.initialFilter = MediaFilter.none,
    this.onPosted,
  });

  @override
  State<CreateEditScreen> createState() => _CreateEditScreenState();
}

class _CreateEditScreenState extends State<CreateEditScreen> {
  VideoPlayerController? _video;
  late MediaFilter _filter = widget.initialFilter;
  RangeValues _range = const RangeValues(0, 1);
  bool _mute = false;
  bool _working = false;
  String _workingText = '';
  // Cartoon can't run live, so it's made once and shown here.
  String? _cartoonPreview;
  VideoPlayerController? _cartoonVideo;

  double get _total => _video?.value.duration.inMilliseconds.toDouble() ?? 1;

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) _loadVideo();
    if (widget.initialFilter.cartoon) _makeCartoonPreview();
  }

  Future<void> _loadVideo() async {
    final v = VideoPlayerController.file(File(widget.path));
    await v.initialize();
    await v.setLooping(true);
    await v.play();
    if (!mounted) {
      await v.dispose();
      return;
    }
    final total = v.value.duration.inMilliseconds.toDouble();
    setState(() {
      _video = v;
      _range = RangeValues(
          0, total.clamp(0, VideoEdit.maxClip.inMilliseconds.toDouble()));
    });
  }

  void _onRange(RangeValues r) {
    final max = VideoEdit.maxClip.inMilliseconds.toDouble();
    var next = r;
    if (next.end - next.start > max) {
      next = r.start != _range.start
          ? RangeValues(next.start, next.start + max)
          : RangeValues(next.end - max, next.end);
    }
    setState(() => _range = next);
    _video?.seekTo(Duration(milliseconds: next.start.round()));
  }

  void _toggleMute() {
    setState(() => _mute = !_mute);
    _video?.setVolume(_mute ? 0 : 1);
    _cartoonVideo?.setVolume(_mute ? 0 : 1);
  }

  Future<void> _selectFilter(MediaFilter f) async {
    setState(() => _filter = f);
    if (f.cartoon) await _makeCartoonPreview();
  }

  Future<void> _makeCartoonPreview() async {
    setState(() {
      _working = true;
      _workingText = 'Making your cartoon…';
    });
    try {
      if (widget.isVideo) {
        while (_video == null && mounted) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
        final out = await VideoEdit.processVideo(
          input: widget.path,
          start: Duration(milliseconds: _range.start.round()),
          end: Duration(milliseconds: _range.end.round()),
          filter: MediaFilter.cartoonLook,
          mute: _mute,
        );
        final v = VideoPlayerController.file(File(out));
        await v.initialize();
        await v.setLooping(true);
        await v.play();
        await _cartoonVideo?.dispose();
        _cartoonVideo = v;
        _video?.pause();
      } else {
        _cartoonPreview = await VideoEdit.processPhoto(
            input: widget.path, filter: MediaFilter.cartoonLook);
      }
    } catch (_) {
      if (mounted) {
        _filter = MediaFilter.none;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Couldn’t make a cartoon of this. Try another clip.')));
      }
    }
    if (mounted) setState(() => _working = false);
  }

  Future<void> _next() async {
    setState(() {
      _working = true;
      _workingText = 'Getting it ready…';
    });
    try {
      final String out;
      if (widget.isVideo) {
        out = await VideoEdit.processVideo(
          input: widget.path,
          start: Duration(milliseconds: _range.start.round()),
          end: Duration(milliseconds: _range.end.round()),
          filter: _filter,
          mute: _mute,
        );
      } else {
        out = await VideoEdit.processPhoto(input: widget.path, filter: _filter);
      }
      if (!mounted) return;
      setState(() => _working = false);
      _video?.pause();
      _cartoonVideo?.pause();
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => CreateCaptionScreen(
                path: out,
                isVideo: widget.isVideo,
                mode: widget.mode,
                onPosted: widget.onPosted,
              )));
    } catch (_) {
      if (!mounted) return;
      setState(() => _working = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Couldn’t edit this. Try again or pick another.')));
    }
  }

  @override
  void dispose() {
    _video?.dispose();
    _cartoonVideo?.dispose();
    super.dispose();
  }

  Widget _preview() {
    if (_filter.cartoon && _cartoonVideo != null) {
      return AspectRatio(
          aspectRatio: _cartoonVideo!.value.aspectRatio,
          child: VideoPlayer(_cartoonVideo!));
    }
    if (_filter.cartoon && _cartoonPreview != null) {
      return Image.file(File(_cartoonPreview!), fit: BoxFit.contain);
    }
    final Widget base;
    final v = _video;
    if (widget.isVideo) {
      if (v == null) return const CircularProgressIndicator();
      base =
          AspectRatio(aspectRatio: v.value.aspectRatio, child: VideoPlayer(v));
    } else {
      base = Image.file(File(widget.path), fit: BoxFit.contain);
    }
    final f = _filter.preview;
    return f == null ? base : ColorFiltered(colorFilter: f, child: base);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Edit'),
        actions: [
          TextButton(
              onPressed: _working ? null : _next, child: const Text('Next')),
        ],
      ),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: Stack(alignment: Alignment.center, children: [
              Center(child: _preview()),
              if (_working)
                Container(
                  color: Colors.black54,
                  alignment: Alignment.center,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 10),
                    Text(_workingText,
                        style: const TextStyle(color: Colors.white)),
                  ]),
                ),
            ]),
          ),
          if (widget.isVideo && _video != null) ...[
            RangeSlider(
              values: _range,
              max: _total,
              onChanged: _working || _filter.cartoon ? null : _onRange,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(children: [
                Expanded(
                  child: Text(
                      'Clip: ${((_range.end - _range.start) / 1000).round()} seconds',
                      style: const TextStyle(color: Colors.white70)),
                ),
                IconButton(
                  tooltip: _mute ? 'Turn sound on' : 'Turn sound off',
                  onPressed: _toggleMute,
                  icon: InIcon(_mute ? InIcons.mute : InIcons.speaker,
                      color: Colors.white),
                ),
              ]),
            ),
          ],
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final f in MediaFilter.all)
                  _FilterChip(
                    label: f.name,
                    selected: f.name == _filter.name,
                    onTap: _working ? () {} : () => _selectFilter(f),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ]),
      ),
    );
  }
}

/// Step 3: caption and share. If sharing fails, everything stays for a retry.
class CreateCaptionScreen extends StatefulWidget {
  final String path;
  final bool isVideo;
  final CreateMode mode;
  final VoidCallback? onPosted;
  const CreateCaptionScreen({
    super.key,
    required this.path,
    required this.isVideo,
    required this.mode,
    this.onPosted,
  });

  @override
  State<CreateCaptionScreen> createState() => _CreateCaptionScreenState();
}

class _CreateCaptionScreenState extends State<CreateCaptionScreen> {
  final _caption = TextEditingController();
  final _location = TextEditingController();
  List<PickedPerson> _tagged = const [];
  bool _comments = true;
  bool _hideLikes = false;
  bool _closeFriends = false;
  bool _sharing = false;

  bool get _story => widget.mode == CreateMode.story;

  /// The server's limit for a clip or photo, once converted for upload.
  static const _videoLimit = 12000000;
  static const _photoLimit = 4000000;

  Future<void> _share() async {
    setState(() => _sharing = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final bytes = await File(widget.path).readAsBytes();
      final data = widget.isVideo
          ? 'data:video/mp4;base64,${base64Encode(bytes)}'
          : 'data:image/jpeg;base64,${base64Encode(bytes)}';
      if (data.length > (widget.isVideo ? _videoLimit : _photoLimit)) {
        messenger.showSnackBar(SnackBar(
            content: Text(widget.isVideo
                ? 'This clip is too large. Trim it a little and try again.'
                : 'This photo is too large. Try another.')));
        if (mounted) setState(() => _sharing = false);
        return;
      }
      await ApiClient.post('/feed', body: {
        'mediaType': widget.isVideo ? 'reel' : 'image',
        'text': _caption.text.trim(),
        'isStory': _story,
        if (widget.isVideo) 'videoData': data else 'imageData': data,
        if (_story && _closeFriends) 'audience': 'closeFriends',
        if (!_story) ...{
          if (_tagged.isNotEmpty)
            'taggedUserIds': [for (final t in _tagged) t.id],
          if (_location.text.trim().isNotEmpty)
            'location': _location.text.trim(),
          'hideLikes': _hideLikes,
          'commentsDisabled': !_comments,
        },
      });
      widget.onPosted?.call();
      navigator.popUntil((r) => r.isFirst);
      messenger.showSnackBar(const SnackBar(content: Text('Shared')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
          content: Text(
              'Couldn’t share this. Check your connection and try again.')));
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  void dispose() {
    _caption.dispose();
    _location.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(switch (widget.mode) {
          CreateMode.reel => 'New reel',
          CreateMode.story => 'New story',
          CreateMode.post => 'New post',
        }),
      ),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(14), children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 84,
                height: 118,
                child: widget.isVideo
                    ? const ColoredBox(
                        color: Color(0xFF2A1F4D),
                        child: Center(
                            child: InIcon(InIcons.film, color: Colors.white)))
                    : Image.file(File(widget.path), fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MentionTextField(
                controller: _caption,
                maxLines: 4,
                maxLength: 1000,
                hintText: 'Write a caption, @ to mention someone…',
              ),
            ),
          ]),
          const SizedBox(height: 6),
          if (_story)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _closeFriends,
              onChanged: (v) => setState(() => _closeFriends = v),
              title: const Text('Close friends only'),
            )
          else ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const InIcon(InIcons.useradd, color: AppColors.text),
              title: const Text('Tag people'),
              trailing: Text(_tagged.isEmpty ? '' : '${_tagged.length}'),
              onTap: () async {
                final picked = await showPeoplePicker(context,
                    title: 'Tag people', initial: _tagged);
                if (picked != null && mounted) {
                  setState(() => _tagged = picked);
                }
              },
            ),
            TextField(
              controller: _location,
              decoration: const InputDecoration(
                  hintText: 'Add location', border: InputBorder.none),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _comments,
              onChanged: (v) => setState(() => _comments = v),
              title: const Text('Allow comments'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _hideLikes,
              onChanged: (v) => setState(() => _hideLikes = v),
              title: const Text('Hide like count'),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _sharing ? null : _share,
            child: Text(_sharing ? 'Sharing…' : 'Share'),
          ),
        ]),
      ),
    );
  }
}
