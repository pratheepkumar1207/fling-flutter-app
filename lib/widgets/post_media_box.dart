import 'package:flutter/material.dart';

import 'app_image.dart';

/// A feed photo at its own shape, the way Instagram does it: anything from
/// 4:5 (tallest) to 1.91:1 (widest). Taller or wider pictures are trimmed
/// from the centre to the nearest allowed shape. Several photos use the
/// first one's shape. Square until the first photo's size is known.
class PostMediaBox extends StatefulWidget {
  final List<String> images;
  final Widget child;
  const PostMediaBox({super.key, required this.images, required this.child});

  static const minRatio = 4 / 5;
  static const maxRatio = 1.91;

  // Shapes already measured, so scrolling back doesn't resize posts.
  static final Map<String, double> _known = {};

  static String _key(String s) =>
      '${s.length}:${s.length > 120 ? s.substring(0, 60) + s.substring(s.length - 60) : s}';

  @override
  State<PostMediaBox> createState() => _PostMediaBoxState();
}

class _PostMediaBoxState extends State<PostMediaBox> {
  double? _ratio;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  String? get _first => widget.images.isEmpty ? null : widget.images.first;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant PostMediaBox old) {
    super.didUpdateWidget(old);
    if (old.images.isEmpty ||
        widget.images.isEmpty ||
        old.images.first != widget.images.first) {
      _stop();
      _ratio = null;
      _resolve();
    }
  }

  void _resolve() {
    final src = _first;
    if (src == null) return;
    final known = PostMediaBox._known[PostMediaBox._key(src)];
    if (known != null) {
      _ratio = known;
      return;
    }
    final provider = AppImage.providerFor(src);
    if (provider == null) return;
    _stream = provider.resolve(ImageConfiguration.empty);
    _listener = ImageStreamListener((info, _) {
      final w = info.image.width, h = info.image.height;
      if (w > 0 && h > 0) {
        final r = (w / h)
            .clamp(PostMediaBox.minRatio, PostMediaBox.maxRatio)
            .toDouble();
        PostMediaBox._known[PostMediaBox._key(src)] = r;
        if (mounted) setState(() => _ratio = r);
      }
      _stop();
    }, onError: (_, __) => _stop());
    _stream!.addListener(_listener!);
  }

  void _stop() {
    final l = _listener;
    if (l != null) _stream?.removeListener(l);
    _listener = null;
    _stream = null;
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      AspectRatio(aspectRatio: _ratio ?? 1, child: widget.child);
}
