import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../models/post.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_image.dart';
import '../../widgets/spinner.dart';
import 'post_detail_screen.dart';

/// 3-column bookmark grid — matches SavedPostsDark.dc.html. Backend already
/// existed (GET /feed/saved, toggled via POST /feed/:id/save from the feed's
/// bookmark icon) — this is the first dedicated screen for it; previously
/// only a plain text-only list buried in the Profile screen.
class SavedPostsScreen extends StatefulWidget {
  const SavedPostsScreen({super.key});

  @override
  State<SavedPostsScreen> createState() => _SavedPostsScreenState();
}

class _SavedPostsScreenState extends State<SavedPostsScreen> {
  bool _loading = true;
  List<Post> _posts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiClient.get('/feed/saved');
      if (!mounted) return;
      setState(() {
        _posts = (data as List).map((e) => Post.fromJson(e as Map<String, dynamic>)).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  static const _placeholderGradients = [
    [Color(0xFFE0C79A), Color(0xFFC17F42)],
    [Color(0xFFE6D0F0), Color(0xFFC896DC)],
    [Color(0xFFE1EEDC), Color(0xFFC2E0B8)],
    [Color(0xFFD9C2E8), Color(0xFFA85CD6)],
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Saved')),
      body: _loading
          ? const Center(child: Spinner())
          : _posts.isEmpty
              ? const Center(child: Text('Nothing saved yet.', style: TextStyle(color: AppColors.textFaint)))
              : GridView.builder(
                  padding: const EdgeInsets.all(2),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 2, crossAxisSpacing: 2),
                  itemCount: _posts.length,
                  itemBuilder: (context, i) {
                    final p = _posts[i];
                    final gradient = _placeholderGradients[p.id.hashCode.abs() % _placeholderGradients.length];
                    return GestureDetector(
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PostDetailScreen(postId: p.id))).then((_) => _load()),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (p.imageData != null)
                            AppImage(source: p.imageData, fit: BoxFit.cover)
                          else
                            Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradient))),
                          if (p.mediaType == 'video_link' || p.mediaType == 'reel')
                            const Positioned(top: 6, right: 6, child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 16)),
                          if (p.mediaType == 'poll')
                            const Positioned(top: 6, right: 6, child: Icon(Icons.bar_chart_rounded, color: Colors.white, size: 16)),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
