import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/video_edit.dart';
import '../../theme/app_colors.dart';
import '../lobby/lobby_create_screen.dart';
import 'create_flow.dart';
import 'text_post_screen.dart';

const _maxPhotos = 5;

const _videoExtensions = {'mp4', 'mov', 'm4v', '3gp', 'webm', 'mkv', 'avi'};

/// A new post starts here. Photos and videos come from the phone's own
/// photo picker (Android's system picker, iOS's PHPicker), so the app never
/// needs access to the whole gallery: you see everything, the app only gets
/// what you pick. Up to five photos make a carousel; one photo or a video
/// goes to the editor. Camera and text posts are a tap away.
class CreateGalleryScreen extends StatefulWidget {
  final VoidCallback? onPosted;
  const CreateGalleryScreen({super.key, this.onPosted});

  @override
  State<CreateGalleryScreen> createState() => _CreateGalleryScreenState();
}

class _CreateGalleryScreenState extends State<CreateGalleryScreen> {
  bool _working = false;

  @override
  void initState() {
    super.initState();
    // Straight into the picker, like opening the gallery used to.
    WidgetsBinding.instance.addPostFrameCallback((_) => _pick());
  }

  static bool _isVideo(XFile f) {
    final mime = f.mimeType;
    if (mime != null) return mime.startsWith('video/');
    final name = f.name.toLowerCase();
    final dot = name.lastIndexOf('.');
    return dot >= 0 && _videoExtensions.contains(name.substring(dot + 1));
  }

  Future<void> _pick() async {
    if (_working) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _working = true);
    try {
      final picked = await ImagePicker().pickMultipleMedia(limit: _maxPhotos);
      if (!mounted || picked.isEmpty) return;
      final photos = picked.where((f) => !_isVideo(f)).toList();
      if (photos.length > 1) {
        // Several photos: a carousel (videos in the same pick are left out).
        final paths = <String>[];
        for (final f in photos.take(_maxPhotos)) {
          paths.add(await VideoEdit.processPhoto(
              input: f.path, filter: MediaFilter.none));
        }
        if (!mounted) return;
        await navigator.push(MaterialPageRoute(
            builder: (_) => CreateCaptionScreen(
                  path: paths.first,
                  extraPaths: paths.skip(1).toList(),
                  isVideo: false,
                  mode: CreateMode.post,
                  onPosted: widget.onPosted,
                )));
      } else {
        final f = photos.isNotEmpty ? photos.first : picked.first;
        final video = _isVideo(f);
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
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _toCamera(CreateMode mode) {
    Navigator.of(context).pushReplacement(MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) =>
            CreateCameraScreen(mode: mode, onPosted: widget.onPosted)));
  }

  Widget _choice(IconData icon, String title, String sub, VoidCallback onTap) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        child: Material(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle, color: Color(0xFF2F2F2F)),
                  child: Icon(icon, color: AppColors.lilac),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15)),
                        const SizedBox(height: 2),
                        Text(sub,
                            style: const TextStyle(
                                color: Colors.white60, fontSize: 12.5)),
                      ]),
                ),
              ]),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('New post'),
      ),
      body: Stack(children: [
        ListView(padding: const EdgeInsets.only(top: 8, bottom: 80), children: [
          _choice(
              Icons.photo_library_outlined,
              _working ? 'Opening…' : 'Choose from your gallery',
              'A photo, a video, or up to $_maxPhotos photos for a carousel',
              _pick),
          _choice(Icons.photo_camera_outlined, 'Camera', 'Take a photo now',
              () => _toCamera(CreateMode.post)),
          _choice(
              Icons.text_fields_rounded,
              'Text post',
              'Words on a colour, with music or a voice note',
              () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => TextPostScreen(
                      mode: CreateMode.post, onPosted: widget.onPosted)))),
        ]),
        Positioned(
          left: 0,
          right: 0,
          bottom: 12,
          child: Center(
            child: Container(
              decoration: BoxDecoration(
                  color: const Color(0xD90E0E0E),
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
}
