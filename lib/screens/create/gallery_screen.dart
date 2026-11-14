import 'dart:typed_data';
import '../../widgets/insync_brand.dart';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../core/video_edit.dart';
import '../../theme/app_colors.dart';
import '../lobby/lobby_create_screen.dart';
import 'create_flow.dart';
import 'text_post_screen.dart';

const _maxPhotos = 5;

/// A new post starts here: a large preview over your photos. Several can be
/// picked for a carousel; the camera and text posts are a tap away.
class CreateGalleryScreen extends StatefulWidget {
  final VoidCallback? onPosted;
  const CreateGalleryScreen({super.key, this.onPosted});

  @override
  State<CreateGalleryScreen> createState() => _CreateGalleryScreenState();
}

class _CreateGalleryScreenState extends State<CreateGalleryScreen> {
  List<AssetPathEntity> _albums = const [];
  AssetPathEntity? _album;
  List<AssetEntity> _assets = const [];
  AssetEntity? _preview;
  final List<AssetEntity> _picked = [];
  bool _many = false;
  bool _loading = true;
  bool _denied = false;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final state = await PhotoManager.requestPermissionExtend();
    if (!state.hasAccess) {
      if (mounted) {
        setState(() {
          _denied = true;
          _loading = false;
        });
      }
      return;
    }
    final albums =
        await PhotoManager.getAssetPathList(type: RequestType.common);
    if (!mounted) return;
    _albums = albums;
    await _open(albums.isEmpty ? null : albums.first);
  }

  Future<void> _open(AssetPathEntity? album) async {
    final assets = album == null
        ? const <AssetEntity>[]
        : await album.getAssetListPaged(page: 0, size: 200);
    if (!mounted) return;
    setState(() {
      _album = album;
      _assets = assets;
      _preview = assets.isEmpty ? null : assets.first;
      _picked.clear();
      _loading = false;
    });
  }

  void _tap(AssetEntity a) {
    setState(() {
      _preview = a;
      if (!_many) return;
      if (_picked.contains(a)) {
        _picked.remove(a);
      } else if (a.type == AssetType.image && _picked.length < _maxPhotos) {
        _picked.add(a);
      }
    });
  }

  void _toggleMany() {
    setState(() {
      _many = !_many;
      _picked.clear();
      final p = _preview;
      if (_many && p != null && p.type == AssetType.image) _picked.add(p);
    });
  }

  Future<void> _next() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _working = true);
    try {
      if (_many && _picked.length > 1) {
        final paths = <String>[];
        for (final a in _picked) {
          final f = await a.file;
          if (f == null) throw StateError('missing');
          paths.add(await VideoEdit.processPhoto(
              input: f.path, filter: MediaFilter.none));
        }
        await navigator.push(MaterialPageRoute(
            builder: (_) => CreateCaptionScreen(
                  path: paths.first,
                  extraPaths: paths.skip(1).toList(),
                  isVideo: false,
                  mode: CreateMode.post,
                  onPosted: widget.onPosted,
                )));
      } else {
        final a = _many && _picked.isNotEmpty ? _picked.first : _preview;
        final f = await a?.file;
        if (a == null || f == null) throw StateError('missing');
        final video = a.type == AssetType.video;
        await navigator.push(MaterialPageRoute(
            builder: (_) => CreateEditScreen(
                  path: f.path,
                  isVideo: video,
                  mode: video ? CreateMode.reel : CreateMode.post,
                  onPosted: widget.onPosted,
                )));
      }
    } catch (_) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Couldn’t open that. Try another.')));
    }
    if (mounted) setState(() => _working = false);
  }

  void _toCamera(CreateMode mode) {
    Navigator.of(context).pushReplacement(MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) =>
            CreateCameraScreen(mode: mode, onPosted: widget.onPosted)));
  }

  // Without gallery access, Android's own picker still works.
  Future<void> _systemPicker() async {
    final navigator = Navigator.of(context);
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null || !mounted) return;
    navigator.push(MaterialPageRoute(
        builder: (_) => CreateEditScreen(
              path: file.path,
              isVideo: false,
              mode: CreateMode.post,
              onPosted: widget.onPosted,
            )));
  }

  Widget _round(Widget child, String label, VoidCallback onTap,
          {bool on = false}) =>
      Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Semantics(
          button: true,
          label: label,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: on ? AppColors.lilac : const Color(0xFF2B2638)),
              child: child,
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).width * .9;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('New post'),
        actions: [
          TextButton(
            onPressed: _preview == null || _working ? null : _next,
            child: Text(_working ? 'Wait…' : 'Next'),
          ),
        ],
      ),
      body: Stack(children: [
        if (_loading)
          const Center(child: InsyncSpinner(size: 32))
        else if (_denied)
          Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Allow photos to see your gallery here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70)),
              ),
              FilledButton(
                  onPressed: PhotoManager.openSetting,
                  child: const Text('Open settings')),
              TextButton(
                  onPressed: _systemPicker,
                  child: const Text('Pick one photo instead')),
            ]),
          )
        else
          Column(children: [
            SizedBox(
              height: height,
              width: double.infinity,
              child: _preview == null
                  ? const Center(
                      child: Text('No photos yet',
                          style: TextStyle(color: Colors.white70)))
                  : _AssetImage(_preview!, large: true),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
              child: Row(children: [
                Expanded(
                  child: DropdownButton<AssetPathEntity>(
                    value: _album,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    dropdownColor: const Color(0xFF17141F),
                    style: const TextStyle(color: Colors.white),
                    items: [
                      for (final a in _albums)
                        DropdownMenuItem(
                            value: a,
                            child: Text(a.isAll ? 'Recents' : a.name,
                                maxLines: 1)),
                    ],
                    onChanged: _open,
                  ),
                ),
                _round(
                    const Text('Aa',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700)),
                    'Text post',
                    () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => TextPostScreen(
                            mode: CreateMode.post,
                            onPosted: widget.onPosted)))),
                _round(
                    Icon(Icons.collections_outlined,
                        size: 18,
                        color: _many ? const Color(0xFF241338) : Colors.white),
                    'Select several',
                    _toggleMany,
                    on: _many),
                _round(
                    const Icon(Icons.photo_camera_outlined,
                        size: 18, color: Colors.white),
                    'Camera',
                    () => _toCamera(CreateMode.post)),
              ]),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.only(bottom: 60),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4, mainAxisSpacing: 2, crossAxisSpacing: 2),
                itemCount: _assets.length,
                itemBuilder: (_, i) {
                  final a = _assets[i];
                  final order = _picked.indexOf(a);
                  return GestureDetector(
                    onTap: () => _tap(a),
                    child: Stack(fit: StackFit.expand, children: [
                      _AssetImage(a),
                      if (a.type == AssetType.video)
                        Positioned(
                          left: 4,
                          bottom: 3,
                          child: Text(_duration(a.videoDuration),
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 11)),
                        ),
                      if (_many && order >= 0)
                        Positioned(
                          right: 4,
                          top: 4,
                          child: CircleAvatar(
                            radius: 10,
                            backgroundColor: AppColors.lilac,
                            child: Text('${order + 1}',
                                style: const TextStyle(
                                    color: Color(0xFF241338), fontSize: 11)),
                          ),
                        ),
                    ]),
                  );
                },
              ),
            ),
          ]),
        Positioned(
          left: 0,
          right: 0,
          bottom: 12,
          child: Center(
            child: Container(
              decoration: BoxDecoration(
                  color: const Color(0xD90B0912),
                  borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                TextButton(
                    onPressed: () {},
                    child: const Text('Post',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700))),
                TextButton(
                    onPressed: () => _toCamera(CreateMode.story),
                    child: const Text('Story',
                        style: TextStyle(color: Colors.white70))),
                TextButton(
                    onPressed: () => _toCamera(CreateMode.reel),
                    child: const Text('Reel',
                        style: TextStyle(color: Colors.white70))),
                TextButton(
                    onPressed: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                            builder: (_) => const LobbyCreateScreen(
                                initialRoomType: 'live'))),
                    child: const Text('Live',
                        style: TextStyle(color: Colors.white70))),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  String _duration(Duration d) =>
      '${d.inMinutes}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';
}

class _AssetImage extends StatelessWidget {
  final AssetEntity asset;
  final bool large;
  const _AssetImage(this.asset, {this.large = false});

  @override
  Widget build(BuildContext context) {
    final size = large ? 1000 : 240;
    return FutureBuilder<Uint8List?>(
      key: ValueKey('${asset.id}-$size'),
      future: asset.thumbnailDataWithSize(ThumbnailSize(size, size)),
      builder: (_, snap) {
        final data = snap.data;
        if (data == null) return const ColoredBox(color: Color(0xFF2B2638));
        return Image.memory(data, fit: BoxFit.cover, gaplessPlayback: true);
      },
    );
  }
}
