import 'package:flutter/material.dart';
import 'app_image.dart';

/// A post's photos: one, or several to swipe through with dots underneath.
class PostImages extends StatefulWidget {
  final List<String> images;
  const PostImages({super.key, required this.images});

  @override
  State<PostImages> createState() => _PostImagesState();
}

class _PostImagesState extends State<PostImages> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final images = widget.images;
    if (images.length == 1) {
      return AppImage(source: images.first, fit: BoxFit.cover);
    }
    return Stack(children: [
      PageView.builder(
        itemCount: images.length,
        onPageChanged: (i) => setState(() => _page = i),
        itemBuilder: (_, i) => AppImage(source: images[i], fit: BoxFit.cover),
      ),
      Positioned(
        top: 10,
        right: 10,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
              color: Colors.black54, borderRadius: BorderRadius.circular(12)),
          child: Text('${_page + 1}/${images.length}',
              style: const TextStyle(color: Colors.white, fontSize: 12)),
        ),
      ),
      Positioned(
        left: 0,
        right: 0,
        bottom: 8,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 0; i < images.length; i++)
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i == _page ? Colors.white : Colors.white54),
            ),
        ]),
      ),
    ]);
  }
}
