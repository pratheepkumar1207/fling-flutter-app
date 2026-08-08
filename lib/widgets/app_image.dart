import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// The backend stores photos as base64 data URIs (no cloud storage
/// provider configured — see Photo/User model comments), not plain URLs, so
/// every image render needs to branch on that instead of just using a
/// network image widget.
class AppImage extends StatelessWidget {
  final String? source;
  final BoxFit fit;
  final Widget Function(BuildContext context)? placeholder;

  const AppImage({super.key, required this.source, this.fit = BoxFit.cover, this.placeholder});

  static Uint8List? _decodeDataUri(String uri) {
    final commaIndex = uri.indexOf(',');
    if (commaIndex == -1) return null;
    try {
      return base64Decode(uri.substring(commaIndex + 1));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final src = source;
    if (src == null || src.isEmpty) {
      return placeholder?.call(context) ?? const SizedBox.shrink();
    }
    if (src.startsWith('data:image')) {
      final bytes = _decodeDataUri(src);
      if (bytes == null) return placeholder?.call(context) ?? const SizedBox.shrink();
      return Image.memory(bytes, fit: fit);
    }
    return CachedNetworkImage(
      imageUrl: src,
      fit: fit,
      placeholder: placeholder != null ? (context, _) => placeholder!(context) : null,
      errorWidget: (context, _, __) => placeholder?.call(context) ?? const SizedBox.shrink(),
    );
  }
}
