import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import '../../core/api_client.dart';
import '../../core/face_filters.dart';
import '../../core/face_tracker.dart';
import '../../core/place_lookup.dart';
import '../../core/video_edit.dart';
import '../../theme/app_colors.dart';
import '../../theme/insync_icons.dart';
import '../../widgets/in_icon_button.dart';
import '../../widgets/mention_text_field.dart';
import '../../widgets/people_picker_sheet.dart';
import '../../widgets/schedule_picker.dart';
import '../../widgets/story_stickers.dart';
import '../../widgets/permission_primer.dart';
import '../lobby/lobby_create_screen.dart';
import 'gallery_screen.dart';
import 'story_editor_screen.dart';
import 'text_post_screen.dart';

enum CreateMode { post, reel, story }

/// Camera first, as on Instagram: record or pick, then edit, then caption.
Future<void> openCreateFlow(BuildContext context,
    {CreateMode mode = CreateMode.reel,
    VoidCallback? onPosted,
    String? addYoursPrompt}) {
  if (mode == CreateMode.post && addYoursPrompt == null) {
    return Navigator.of(context).push(MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => CreateGalleryScreen(onPosted: onPosted)));
  }
  return Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => CreateCameraScreen(
          mode: mode, onPosted: onPosted, addYoursPrompt: addYoursPrompt)));
}

class CreateCameraScreen extends StatefulWidget {
  final CreateMode mode;
  final VoidCallback? onPosted;
  final String? addYoursPrompt;
  const CreateCameraScreen(
      {super.key, required this.mode, this.onPosted, this.addYoursPrompt});

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
  // Hands-free: the shutter waits this long.
  int _timer = 0;
  int? _countdown;
  bool _gridLines = false;

  final _tracker = FaceTracker();
  FaceFilter? _faceFilter;
  FacePose? _pose;
  DateTime _poseSeen = DateTime.now();
  String _faceGroup = FaceFilter.groups.first;
  bool _showFaces = false;
  bool _stream = false;
  bool _baking = false;
  DateTime? _recordStart;
  final List<List<double>> _track = [];

  MediaFilter get _look => MediaFilter.colour[_filter];
  bool get _mirrored =>
      _cameras.isNotEmpty &&
      _cameras[_cameraIndex].lensDirection == CameraLensDirection.front;

  void _onFrame(CameraImage image) async {
    final FacePose? found;
    try {
      found = await _tracker.detect(
          image, _cameras[_cameraIndex].sensorOrientation);
    } catch (_) {
      if (!mounted || _faceFilter == null) return;
      setState(() => _faceFilter = null);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Face filters couldn’t start on this phone.')));
      return;
    }
    if (found == null || !mounted) return;
    final start = _recordStart;
    final pose = _pose?.smoothedTo(found) ?? found;
    if (start != null) {
      _track.add(pose.toRow(DateTime.now().difference(start).inMilliseconds));
    }
    _poseSeen = DateTime.now();
    setState(() => _pose = pose);
  }

  /// Frames only flow while a face filter is on, to spare the battery.
  Future<void> _syncStream() async {
    final c = _camera;
    if (c == null || _recording) return;
    final want = _faceFilter != null;
    if (want == _stream) return;
    _stream = want;
    if (want) {
      await c.startImageStream(_onFrame);
    } else {
      await c.stopImageStream();
    }
  }

  // The swipeable bubbles around the shutter: "none", then every filter.
  final _bubbles = PageController(viewportFraction: 0.2);

  void _pickFace(FaceFilter? f) {
    if (f?.id == _faceFilter?.id) return;
    if (_bubbles.hasClients) {
      final page = f == null ? 0 : FaceFilter.all.indexOf(f) + 1;
      if (_bubbles.page?.round() != page) _bubbles.jumpToPage(page);
    }
    setState(() {
      _faceFilter = f;
      if (f == null) _pose = null;
    });
    _syncStream();
  }

  /// Puts the chosen sticker on a finished photo; null if no face is in it.
  Future<String?> _bakePhoto(String path) async {
    final f = _faceFilter;
    if (f == null) return path;
    return FaceTracker.bakePhoto(input: path, sticker: await f.renderSticker());
  }

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

  /// One camera at a time: closing the old one after opening the new one
  /// shuts the new one off too, leaving a black screen.
  Future<void> _openCamera() async {
    final previous = _camera;
    if (previous != null) {
      setState(() {
        _camera = null;
        _pose = null;
      });
      _stream = false;
      _flash = false;
      await _closeCamera(previous);
      if (!mounted) return;
    }
    final next = CameraController(_cameras[_cameraIndex], ResolutionPreset.high,
        enableAudio: true, imageFormatGroup: ImageFormatGroup.yuv420);
    await next.initialize();
    if (!mounted) {
      await _closeCamera(next);
      return;
    }
    setState(() => _camera = next);
    await _syncStream();
  }

  // The camera plugin can throw while closing; it's closed either way.
  Future<void> _closeCamera(CameraController c) async {
    try {
      await c.dispose();
    } catch (_) {}
  }

  bool _flipping = false;

  Future<void> _flip() async {
    if (_cameras.length < 2 || _recording || _flipping) return;
    _flipping = true;
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    try {
      await _openCamera();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Couldn’t switch camera. Try again.')));
      }
    }
    _flipping = false;
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
    if (_countdown != null) {
      setState(() => _countdown = null); // A second tap cancels it.
      return;
    }
    if (_timer > 0 && !_recording) {
      for (var left = _timer; left > 0; left--) {
        if (!mounted) return;
        setState(() => _countdown = left);
        await Future<void>.delayed(const Duration(seconds: 1));
        if (_countdown == null) return;
      }
      if (!mounted) return;
      setState(() => _countdown = null);
    }
    if (_recording) {
      await _stop();
      return;
    }
    if (_mode != CreateMode.reel) {
      await _takePhoto(c);
      return;
    }
    await _record(c);
  }

  /// Stories record while the shutter is held, as well as taking photos.
  Future<void> _record(CameraController c) async {
    // A running stream must stop first; recording brings its own frames.
    if (_stream) {
      await c.stopImageStream();
      _stream = false;
    }
    _track.clear();
    await c.startVideoRecording(
        onAvailable: _faceFilter == null ? null : _onFrame);
    _recordStart = DateTime.now();
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
    _recordStart = null;
    if (!mounted) return;
    setState(() => _recording = false);
    final f = _faceFilter;
    var path = clip.path;
    if (f != null) {
      setState(() => _baking = true);
      try {
        path = await FaceTracker.bakeVideo(
            input: path,
            sticker: await f.renderSticker(),
            track: List.of(_track));
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content:
                  Text('Couldn’t add the filter, so this is the plain clip.')));
        }
      }
      if (!mounted) return;
      setState(() => _baking = false);
    }
    await _syncStream();
    if (mounted) _edit(path, isVideo: true);
  }

  Future<void> _takePhoto(CameraController c) async {
    // Some phones can't take a photo during a frame stream.
    if (_stream) {
      await c.stopImageStream();
      _stream = false;
    }
    setState(() => _baking = _faceFilter != null);
    String path;
    try {
      final shot = await c.takePicture();
      final baked = await _bakePhoto(shot.path);
      if (baked == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No face found, so this is the plain photo.')));
      }
      path = baked ?? shot.path;
    } catch (_) {
      if (mounted) {
        setState(() => _baking = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Couldn’t take that photo. Try again.')));
      }
      await _syncStream();
      return;
    }
    if (!mounted) return;
    setState(() => _baking = false);
    await _syncStream();
    if (mounted) _edit(path, isVideo: false);
  }

  Future<void> _gallery() async {
    final picker = ImagePicker();
    if (_mode == CreateMode.post) {
      final photos = await picker.pickMultiImage(limit: 5);
      if (photos.isEmpty || !mounted) return;
      if (photos.length == 1) {
        _edit(photos.first.path, isVideo: false);
      } else {
        await _shareSeveral(photos);
      }
      return;
    }
    final file = switch (_mode) {
      CreateMode.reel => await picker.pickVideo(source: ImageSource.gallery),
      CreateMode.story => await picker.pickMedia(),
      CreateMode.post => await picker.pickImage(source: ImageSource.gallery),
    };
    if (file == null || !mounted) return;
    final isVideo = _mode == CreateMode.reel ||
        (_mode == CreateMode.story &&
            RegExp(r'\.(mp4|mov|m4v|3gp|webm|mkv)$', caseSensitive: false)
                .hasMatch(file.path));
    _edit(file.path, isVideo: isVideo);
  }

  /// A set goes straight to the caption, made small enough to upload.
  Future<void> _shareSeveral(List<XFile> photos) async {
    setState(() => _baking = true);
    try {
      final paths = <String>[];
      for (final photo in photos.take(5)) {
        paths.add(await VideoEdit.processPhoto(
            input: photo.path, filter: MediaFilter.none));
      }
      if (!mounted) return;
      setState(() => _baking = false);
      await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => CreateCaptionScreen(
                path: paths.first,
                extraPaths: paths.skip(1).toList(),
                isVideo: false,
                mode: CreateMode.post,
                onPosted: widget.onPosted,
              )));
    } catch (_) {
      if (!mounted) return;
      setState(() => _baking = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Couldn’t get those photos ready. Try again.')));
    }
  }

  void _edit(String path, {required bool isVideo}) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CreateEditScreen(
              path: path,
              isVideo: isVideo,
              mode: _mode,
              initialFilter: _look,
              onPosted: widget.onPosted,
              addYoursPrompt: widget.addYoursPrompt,
            )));
  }

  void _goLive() => Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => const LobbyCreateScreen(initialRoomType: 'live')));

  /// The shutter sits over the bubbles; the chosen filter lands under it.
  Widget _shutterRow() {
    final shutter = Semantics(
      button: true,
      label: _mode != CreateMode.reel
          ? 'Take photo'
          : _recording
              ? 'Stop recording'
              : 'Record',
      child: GestureDetector(
        onTap: _shutter,
        onLongPressStart: _mode == CreateMode.story && !_recording
            ? (_) {
                final c = _camera;
                if (c != null) _record(c);
              }
            : null,
        onLongPressEnd: _mode == CreateMode.story ? (_) => _stop() : null,
        child: Container(
          width: 76,
          height: 76,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4)),
          child: _recording
              ? DecoratedBox(
                  decoration: BoxDecoration(
                      color: const Color(0xFFE0364F),
                      borderRadius: BorderRadius.circular(8)))
              : null,
        ),
      ),
    );
    if (!FaceTracker.supported) return Center(child: shutter);
    return SizedBox(
      height: 84,
      child: Stack(alignment: Alignment.center, children: [
        PageView.builder(
          controller: _bubbles,
          physics: _recording ? const NeverScrollableScrollPhysics() : null,
          itemCount: FaceFilter.all.length + 1,
          onPageChanged: (i) =>
              _pickFace(i == 0 ? null : FaceFilter.all[i - 1]),
          itemBuilder: (_, i) => Center(
            child: GestureDetector(
              onTap: () => _bubbles.animateToPage(i,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut),
              child: Container(
                width: 52,
                height: 52,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white54)),
                child: i == 0
                    ? const Icon(Icons.block_rounded, color: Colors.white70)
                    : FaceFilterThumb(FaceFilter.all[i - 1]),
              ),
            ),
          ),
        ),
        shutter,
      ]),
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    final camera = _camera;
    if (camera != null) _closeCamera(camera);
    _bubbles.dispose();
    if (FaceTracker.supported) FaceTracker.release();
    super.dispose();
  }

  void _nextFilter(int by) => setState(() =>
      _filter = (_filter + by).clamp(0, MediaFilter.colour.length - 1).toInt());

  /// The picture and its sticker share one box, so the sticker lines up with
  /// the face. The colour look stays on the picture, as it does when saved.
  Widget _cameraView(CameraController c) {
    final look = _look.preview;
    final f = _faceFilter;
    final pose = _pose;
    final visible = pose != null &&
        DateTime.now().difference(_poseSeen) <
            const Duration(milliseconds: 500);
    return AspectRatio(
      aspectRatio: 1 / c.value.aspectRatio,
      child: Stack(fit: StackFit.expand, children: [
        look == null
            ? CameraPreview(c)
            : ColorFiltered(colorFilter: look, child: CameraPreview(c)),
        if (f != null && visible)
          FaceFilterOverlay(filter: f, pose: pose, mirrored: _mirrored),
        if (_gridLines) const IgnorePointer(child: _ThirdsGrid()),
      ]),
    );
  }

  Widget _faceTray() {
    final inGroup = FaceFilter.all.where((f) => f.group == _faceGroup).toList();
    return Column(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(
        height: 34,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [
            for (final g in FaceFilter.groups)
              _FilterChip(
                label: g,
                selected: g == _faceGroup,
                onTap: () => setState(() => _faceGroup = g),
              ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      SizedBox(
        height: 72,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: inGroup.length + 1,
          itemBuilder: (_, i) {
            if (i == 0) {
              return _FaceTile(
                label: 'None',
                selected: _faceFilter == null,
                onTap: () => _pickFace(null),
                child: const Icon(Icons.block_rounded, color: Colors.white70),
              );
            }
            final f = inGroup[i - 1];
            return _FaceTile(
              label: f.name,
              selected: _faceFilter?.id == f.id,
              onTap: () => _pickFace(f),
              child: FaceFilterThumb(f),
            );
          },
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final c = _camera;
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
            child: Center(child: _cameraView(c)),
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
              if (!_recording && _mode != CreateMode.reel)
                TextButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => TextPostScreen(
                          mode: _mode, onPosted: widget.onPosted))),
                  child: const Text('Aa',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                ),
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
                tooltip: _gridLines ? 'Grid off' : 'Grid on',
                onPressed: () => setState(() => _gridLines = !_gridLines),
                icon: Icon(
                    _gridLines ? Icons.grid_on_rounded : Icons.grid_off_rounded,
                    color: Colors.white),
              ),
              TextButton(
                onPressed: _recording
                    ? null
                    : () => setState(() => _timer = switch (_timer) {
                          0 => 3,
                          3 => 10,
                          _ => 0,
                        }),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.timer_outlined, color: Colors.white),
                  if (_timer > 0)
                    Text(' ${_timer}s',
                        style: const TextStyle(color: Colors.white)),
                ]),
              ),
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
            if (_showFaces && !_recording)
              _faceTray()
            else
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
            _shutterRow(),
            Row(children: [
              IconButton(
                tooltip: 'Choose from gallery',
                iconSize: 30,
                onPressed: _recording ? null : _gallery,
                icon: const Icon(Icons.photo_library_rounded,
                    color: Colors.white),
              ),
              const Spacer(),
              if (FaceTracker.supported)
                IconButton(
                  tooltip: _showFaces ? 'Colour filters' : 'All face filters',
                  iconSize: 30,
                  onPressed: _recording
                      ? null
                      : () => setState(() => _showFaces = !_showFaces),
                  icon: Icon(
                      _showFaces
                          ? Icons.palette_outlined
                          : Icons.face_retouching_natural_rounded,
                      color: Colors.white),
                ),
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
              TextButton(
                onPressed: _recording ? null : _goLive,
                child:
                    const Text('Live', style: TextStyle(color: Colors.white70)),
              ),
            ]),
          ]),
        ),
        if (_countdown != null)
          IgnorePointer(
            child: Center(
              child: Text('$_countdown',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 110,
                      fontWeight: FontWeight.w800,
                      shadows: [
                        Shadow(color: Colors.black54, blurRadius: 10)
                      ])),
            ),
          ),
        if (_baking)
          Container(
            color: Colors.black54,
            alignment: Alignment.center,
            child: const Column(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(),
              SizedBox(height: 10),
              Text('Getting it ready…', style: TextStyle(color: Colors.white)),
            ]),
          ),
      ]),
    );
  }
}

/// Thirds lines, to help framing. Never saved in the picture.
class _ThirdsGrid extends StatelessWidget {
  const _ThirdsGrid();

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _ThirdsPainter());
}

class _ThirdsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = Colors.white54
      ..strokeWidth = 1;
    for (final t in const [1 / 3, 2 / 3]) {
      canvas.drawLine(
          Offset(size.width * t, 0), Offset(size.width * t, size.height), line);
      canvas.drawLine(Offset(0, size.height * t),
          Offset(size.width, size.height * t), line);
    }
  }

  @override
  bool shouldRepaint(_ThirdsPainter old) => false;
}

class _FaceTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  const _FaceTile(
      {required this.label,
      required this.selected,
      required this.onTap,
      required this.child});

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 64,
            margin: const EdgeInsets.only(right: 8),
            child: Column(children: [
              Container(
                width: 50,
                height: 50,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: selected ? AppColors.lilac : Colors.white24,
                      width: selected ? 3 : 1),
                ),
                child: child,
              ),
              const SizedBox(height: 4),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 10)),
            ]),
          ),
        ),
      );
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
  final String? addYoursPrompt;
  const CreateEditScreen({
    super.key,
    required this.path,
    required this.isVideo,
    required this.mode,
    this.initialFilter = MediaFilter.none,
    this.onPosted,
    this.addYoursPrompt,
  });

  @override
  State<CreateEditScreen> createState() => _CreateEditScreenState();
}

class _CreateEditScreenState extends State<CreateEditScreen> {
  VideoPlayerController? _video;
  late MediaFilter _filter = widget.initialFilter;
  RangeValues _range = const RangeValues(0, 1);
  bool _mute = false;
  double _speed = 1;
  double _volume = 1;
  double _brightness = 0;
  double _contrast = 0;
  double _warmth = 0;
  double _saturation = 0;
  double _fade = 0;
  int _turns = 0;
  double? _aspect;
  bool _showAdjust = false;
  final List<Map<String, dynamic>> _texts = [];
  final _textLayer = GlobalKey();
  double _startScale = 1;
  double _startRotation = 0;
  Offset? _grab;
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

  Future<void> _editText([Map<String, dynamic>? existing]) async {
    final result = await Navigator.of(context).push<Map<String, String>>(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black54,
        pageBuilder: (_, __, ___) => StoryTextEditor(
          text: existing?['text'] as String? ?? '',
          color: existing?['color'] as String? ?? 'white',
          font: existing?['font'] as String? ?? 'classic',
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      final empty = result['text']!.isEmpty;
      if (existing != null) {
        empty ? _texts.remove(existing) : existing.addAll(result);
      } else if (!empty) {
        _texts.add(
            {'x': 0.5, 'y': 0.5, 'scale': 1.0, 'rotation': 0.0, ...result});
      }
    });
  }

  /// The text as a transparent picture, baked into the clip by Android.
  Future<String?> _captureText() async {
    if (_texts.isEmpty) return null;
    final box =
        _textLayer.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (box == null) return null;
    final image = await box.toImage(pixelRatio: 720 / box.size.width);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (png == null) return null;
    final dir = await getTemporaryDirectory();
    final file =
        File('${dir.path}/clip_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(png.buffer.asUint8List());
    return file.path;
  }

  /// A clip with its text on top, sharing one box so what's seen is what's
  /// saved.
  Widget _clipWithText(double aspect, Widget clip) => AspectRatio(
        aspectRatio: aspect,
        child: Stack(fit: StackFit.expand, children: [
          clip,
          LayoutBuilder(builder: (context, box) {
            final frame = box.biggest;
            return RepaintBoundary(
              key: _textLayer,
              child: Stack(fit: StackFit.expand, children: [
                for (final t in _texts)
                  PlacedSticker(
                    sticker: t,
                    frame: frame,
                    child: GestureDetector(
                      onTap: () => _editText(t),
                      onScaleStart: (_) {
                        _startScale = (t['scale'] as num).toDouble();
                        _startRotation = (t['rotation'] as num).toDouble();
                        _grab = null;
                      },
                      onScaleUpdate: (d) {
                        final layer = _textLayer.currentContext
                            ?.findRenderObject() as RenderBox?;
                        if (layer == null) return;
                        final at = layer.globalToLocal(d.focalPoint);
                        _grab ??= Offset(at.dx - (t['x'] as num) * frame.width,
                            at.dy - (t['y'] as num) * frame.height);
                        setState(() {
                          t['x'] = ((at.dx - _grab!.dx) / frame.width)
                              .clamp(0.0, 1.0);
                          t['y'] = ((at.dy - _grab!.dy) / frame.height)
                              .clamp(0.0, 1.0);
                          t['scale'] = (_startScale * d.scale).clamp(0.3, 5.0);
                          t['rotation'] = _startRotation + d.rotation;
                        });
                      },
                      child: StickerBody(sticker: {'type': 'text', ...t}),
                    ),
                  ),
              ]),
            );
          }),
        ]),
      );

  MediaFilter get _look => _filter.adjusted(
      brightness: _brightness,
      contrast: _contrast,
      warmth: _warmth,
      saturation: _saturation,
      fade: _fade);

  Widget _slider(String label, double value, ValueChanged<double> onChanged,
          {double min = -1}) =>
      Row(children: [
        SizedBox(
            width: 82,
            child: Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 12.5))),
        Expanded(
          child: Slider(value: value, min: min, max: 1, onChanged: onChanged),
        ),
      ]);

  Widget _adjustPanel() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        constraints: const BoxConstraints(maxHeight: 220),
        child: ListView(shrinkWrap: true, children: [
          _slider('Brightness', _brightness,
              (v) => setState(() => _brightness = v)),
          _slider('Contrast', _contrast, (v) => setState(() => _contrast = v)),
          _slider('Warmth', _warmth, (v) => setState(() => _warmth = v)),
          _slider('Saturation', _saturation,
              (v) => setState(() => _saturation = v)),
          _slider('Fade', _fade, (v) => setState(() => _fade = v), min: 0),
          if (widget.isVideo)
            _slider('Volume', _volume, (v) {
              setState(() => _volume = v);
              _video?.setVolume(v);
            }, min: 0),
        ]),
      );

  /// Photos only: turn a quarter, or crop to a common shape.
  Widget _cropRow() => SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [
            IconButton(
              tooltip: 'Rotate',
              onPressed: () => setState(() => _turns = (_turns + 1) % 4),
              icon: const Icon(Icons.rotate_right_rounded, color: Colors.white),
            ),
            for (final (label, value) in const <(String, double?)>[
              ('Original', null),
              ('1:1', 1.0),
              ('4:5', 0.8),
              ('9:16', 9 / 16),
              ('16:9', 16 / 9),
            ])
              _FilterChip(
                label: label,
                selected: _aspect == value,
                onTap: () => setState(() => _aspect = value),
              ),
          ],
        ),
      );

  void _setSpeed(double speed) {
    setState(() => _speed = speed);
    _video?.setPlaybackSpeed(speed);
    _cartoonVideo?.setPlaybackSpeed(speed);
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
          filter: _look,
          mute: _mute,
          speed: _speed,
          volume: _volume,
          overlay: await _captureText(),
        );
      } else {
        out = await VideoEdit.processPhoto(
            input: widget.path, filter: _look, turns: _turns, aspect: _aspect);
      }
      if (!mounted) return;
      setState(() => _working = false);
      _video?.pause();
      _cartoonVideo?.pause();
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => widget.mode == CreateMode.story
              ? StoryEditorScreen(
                  path: out,
                  isVideo: widget.isVideo,
                  onPosted: widget.onPosted,
                  addYoursPrompt: widget.addYoursPrompt,
                )
              : CreateCaptionScreen(
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
      return _clipWithText(
          _cartoonVideo!.value.aspectRatio, VideoPlayer(_cartoonVideo!));
    }
    if (_filter.cartoon && _cartoonPreview != null) {
      return Image.file(File(_cartoonPreview!), fit: BoxFit.contain);
    }
    final Widget base;
    final v = _video;
    if (widget.isVideo) {
      if (v == null) return const CircularProgressIndicator();
      final f = _look.preview;
      final player = VideoPlayer(v);
      return _clipWithText(v.value.aspectRatio,
          f == null ? player : ColorFiltered(colorFilter: f, child: player));
    } else {
      base = Image.file(File(widget.path), fit: BoxFit.contain);
    }
    final f = _look.preview;
    Widget shaped = RotatedBox(quarterTurns: _turns, child: base);
    final a = _aspect;
    if (a != null && !widget.isVideo) {
      shaped = AspectRatio(
          aspectRatio: a,
          child: ClipRect(child: FittedBox(fit: BoxFit.cover, child: shaped)));
    }
    return f == null ? shaped : ColorFiltered(colorFilter: f, child: shaped);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Edit'),
        actions: [
          IconButton(
            tooltip: 'Adjust',
            onPressed: () => setState(() => _showAdjust = !_showAdjust),
            icon: Icon(Icons.tune_rounded,
                color: _showAdjust ? AppColors.lilac : Colors.white),
          ),
          if (widget.isVideo && widget.mode != CreateMode.story)
            IconButton(
              tooltip: 'Add text',
              onPressed: _working ? null : () => _editText(),
              icon: const Icon(Icons.text_fields_rounded),
            ),
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
                      'Clip: ${((_range.end - _range.start) / 1000 / _speed).round()} seconds',
                      style: const TextStyle(color: Colors.white70)),
                ),
                PopupMenuButton<double>(
                  tooltip: 'Speed',
                  initialValue: _speed,
                  onSelected: _setSpeed,
                  itemBuilder: (_) => [
                    for (final v in const [0.5, 1.0, 1.5, 2.0])
                      PopupMenuItem(
                          value: v, child: Text(v == 1 ? 'Normal' : '${v}x')),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(_speed == 1 ? '1x' : '${_speed}x',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
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
          if (_showAdjust) _adjustPanel(),
          if (!widget.isVideo) _cropRow(),
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

  /// More photos in a carousel, after [path].
  final List<String> extraPaths;

  /// From the Aa screen: what to post instead of a file.
  final Map<String, dynamic>? textPost;
  final String? textPostText;
  final Color? textPostColour;
  const CreateCaptionScreen({
    super.key,
    this.extraPaths = const [],
    this.textPost,
    this.textPostText,
    this.textPostColour,
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
  PickedPerson? _collaborator;
  bool _comments = true;
  bool _hideLikes = false;
  bool _closeFriends = false;
  bool _sharing = false;
  String? _cover;
  DateTime? _publishAt;

  bool get _story => widget.mode == CreateMode.story;

  /// The server's limit for a clip or photo, once converted for upload.
  static const _videoLimit = 12000000;
  static const _photoLimit = 4000000;

  Future<void> _share() async {
    setState(() => _sharing = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final textPost = widget.textPost;
      final bytes = textPost != null
          ? const <int>[]
          : await File(widget.path).readAsBytes();
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
        if (textPost != null)
          ...textPost
        else if (widget.isVideo)
          'videoData': data
        else
          'imageData': data,
        if (widget.extraPaths.isNotEmpty)
          'extraImages': [
            for (final path in widget.extraPaths)
              'data:image/jpeg;base64,${base64Encode(await File(path).readAsBytes())}',
          ],
        if (_cover != null)
          'coverData':
              'data:image/jpeg;base64,${base64Encode(await File(_cover!).readAsBytes())}',
        if (_story && _closeFriends) 'audience': 'closeFriends',
        if (!_story) ...{
          if (_tagged.isNotEmpty)
            'taggedUserIds': [for (final t in _tagged) t.id],
          if (_collaborator != null) 'collaboratorId': _collaborator!.id,
          if (_location.text.trim().isNotEmpty)
            'location': _location.text.trim(),
          'hideLikes': _hideLikes,
          'commentsDisabled': !_comments,
          if (_publishAt != null)
            'publishAt': _publishAt!.toUtc().toIso8601String(),
        },
      });
      widget.onPosted?.call();
      navigator.popUntil((r) => r.isFirst);
      messenger.showSnackBar(SnackBar(
          content: Text(_publishAt == null
              ? 'Shared'
              : 'Scheduled. It waits in your archive.')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
          content: Text(
              'Couldn’t share this. Check your connection and try again.')));
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) _pickCoverAt(Duration.zero);
    _caption.text = widget.textPostText ?? '';
  }

  Future<void> _pickCoverAt(Duration at) async {
    try {
      final path = await VideoEdit.videoFrame(input: widget.path, at: at);
      if (mounted) setState(() => _cover = path);
    } catch (_) {
      // The reel still posts, and just shows a plain tile while loading.
    }
  }

  // Slide through the clip and keep the frame showing.
  Future<void> _chooseCover() async {
    final v = VideoPlayerController.file(File(widget.path));
    await v.initialize();
    if (!mounted) {
      await v.dispose();
      return;
    }
    var at = 0.0;
    final total = v.value.duration.inMilliseconds.toDouble();
    final chosen = await showModalBottomSheet<Duration>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                height: 260,
                child: AspectRatio(
                    aspectRatio: v.value.aspectRatio, child: VideoPlayer(v)),
              ),
              Slider(
                value: at,
                max: total <= 0 ? 1 : total,
                onChanged: (n) {
                  set(() => at = n);
                  v.seekTo(Duration(milliseconds: n.round()));
                },
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.of(ctx).pop(Duration(milliseconds: at.round())),
                child: const Text('Use this as the cover'),
              ),
            ]),
          ),
        ),
      ),
    );
    await v.dispose();
    if (chosen != null) await _pickCoverAt(chosen);
  }

  Future<void> _useMyLocation() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final place = await currentPlaceName();
      if (mounted) _location.text = place;
    } on PlaceLookupFailure catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _saveToPhone() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await VideoEdit.saveToGallery(
          input: widget.path, isVideo: widget.isVideo);
      messenger
          .showSnackBar(const SnackBar(content: Text('Saved to your phone')));
    } catch (_) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Couldn’t save this to your phone.')));
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
        actions: [
          IconButton(
            tooltip: 'Save to phone',
            onPressed: _saveToPhone,
            icon: const Icon(Icons.download_rounded),
          ),
        ],
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
                    ? Semantics(
                        button: true,
                        label: 'Edit cover',
                        child: GestureDetector(
                          onTap: _chooseCover,
                          child: Stack(fit: StackFit.expand, children: [
                            _cover == null
                                ? const ColoredBox(color: Color(0xFF2A1F4D))
                                : Image.file(File(_cover!), fit: BoxFit.cover),
                            const Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: ColoredBox(
                                color: Colors.black54,
                                child: Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Text('Edit cover',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 11)),
                                ),
                              ),
                            ),
                          ]),
                        ),
                      )
                    : Stack(fit: StackFit.expand, children: [
                        widget.textPost != null
                            ? ColoredBox(
                                color: widget.textPostColour ?? Colors.black)
                            : Image.file(File(widget.path), fit: BoxFit.cover),
                        if (widget.extraPaths.isNotEmpty)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(9)),
                              child: Text('1/${widget.extraPaths.length + 1}',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 11)),
                            ),
                          ),
                      ]),
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
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const InIcon(InIcons.users, color: AppColors.text),
              title: const Text('Add a collaborator'),
              trailing: Text(_collaborator?.name ?? ''),
              onTap: () async {
                final picked = await showPeoplePicker(context,
                    title: 'Add a collaborator',
                    single: true,
                    initial: [if (_collaborator != null) _collaborator!]);
                if (picked != null && mounted) {
                  setState(() => _collaborator = picked.firstOrNull);
                }
              },
            ),
            TextField(
              controller: _location,
              maxLength: 80,
              decoration: InputDecoration(
                  hintText: 'Add location',
                  counterText: '',
                  border: InputBorder.none,
                  suffixIcon: IconButton(
                    tooltip: 'Use my location',
                    onPressed: _useMyLocation,
                    icon: const Icon(Icons.my_location_rounded),
                  )),
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
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_publishAt == null
                  ? 'Post now'
                  : 'Goes out ${postTimeLabel(context, _publishAt!)}'),
              trailing: TextButton(
                onPressed: () async {
                  if (_publishAt != null) {
                    setState(() => _publishAt = null);
                    return;
                  }
                  final t = await pickPostTime(context);
                  if (t != null && mounted) setState(() => _publishAt = t);
                },
                child: Text(_publishAt == null ? 'Schedule' : 'Cancel'),
              ),
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
