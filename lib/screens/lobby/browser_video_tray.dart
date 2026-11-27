import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/insync_icons.dart';
import '../../widgets/app_image.dart';

/// A video the Browser found on the page (see webview_browse_screen.dart's
/// _findVideosJs): something on the page itself, or an embedded YouTube or
/// Vimeo player.
class FoundVideo {
  final String key;
  final String title;
  final String? thumbnail;
  final int? durationSec;
  final String videoUrl;
  final String sourceType; // 'youtube' | 'web'
  final String site;
  // A protected video (the site won't let other apps play it).
  final bool locked;
  const FoundVideo({
    required this.key,
    required this.title,
    required this.videoUrl,
    required this.sourceType,
    required this.site,
    this.thumbnail,
    this.durationSec,
    this.locked = false,
  });

  Map<String, dynamic> toQueueItem() => {
        'videoUrl': videoUrl,
        'title': title,
        'thumbnail': thumbnail,
        'sourceType': sourceType,
        'mediaMode': 'video',
      };

  String? get durationLabel {
    final d = durationSec;
    if (d == null || d <= 0) return null;
    final h = d ~/ 3600, m = (d % 3600) ~/ 60, s = d % 60;
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$ss' : '$m:$ss';
  }
}

/// Thumbnail with a play icon (or a lock), the length, and an optional
/// tick for picking several.
class _Thumb extends StatelessWidget {
  final FoundVideo video;
  final double width;
  final double height;
  final bool? ticked; // null: not picking
  const _Thumb(this.video,
      {required this.width, required this.height, this.ticked});

  @override
  Widget build(BuildContext context) {
    final thumb = video.thumbnail;
    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF000000),
        borderRadius: BorderRadius.circular(10),
        border: ticked == true
            ? Border.all(color: AppColors.lilac, width: 3)
            : null,
      ),
      child: Stack(fit: StackFit.expand, children: [
        if (thumb != null && thumb.isNotEmpty)
          AppImage(source: thumb, fit: BoxFit.cover),
        if (ticked == null)
          Center(
            child: Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                  color: Colors.black54, shape: BoxShape.circle),
              child: Center(
                  child: video.locked
                      ? const InIcon(InIcons.lock,
                          size: 14, color: Colors.white)
                      : const InIcon(InIcons.play,
                          size: 14, color: Colors.white, filled: true)),
            ),
          ),
        if (ticked != null)
          Positioned(
            left: 6,
            top: 6,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ticked! ? AppColors.lilac : Colors.black38,
                border: Border.all(
                    color: ticked! ? AppColors.lilac : Colors.white, width: 2),
              ),
              child: ticked!
                  ? const Icon(Icons.check, size: 14, color: Color(0xFFFFFFFF))
                  : null,
            ),
          ),
        if (video.durationLabel != null)
          Positioned(
            right: 5,
            bottom: 5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(5)),
              child: Text(video.durationLabel!,
                  style: const TextStyle(color: Colors.white, fontSize: 10)),
            ),
          ),
      ]),
    );
  }
}

/// One video on the page: a small player card floating at the bottom
/// centre. While the page scrolls it shrinks to a pill ([collapsed]).
class BrowserVideoCard extends StatelessWidget {
  final FoundVideo video;
  final bool collapsed;
  final VoidCallback onWatch;
  final VoidCallback onClose;
  final VoidCallback onExpand;
  const BrowserVideoCard(
      {super.key,
      required this.video,
      required this.collapsed,
      required this.onWatch,
      required this.onClose,
      required this.onExpand});

  @override
  Widget build(BuildContext context) {
    final border = Border.all(color: AppColors.lilac.withValues(alpha: 0.5));
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: collapsed
          ? Semantics(
              key: const ValueKey('pill'),
              button: true,
              label: 'Video on this page, ${video.title}',
              child: GestureDetector(
                onTap: onExpand,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(5, 5, 14, 5),
                  decoration: BoxDecoration(
                      color: const Color(0xFF000000),
                      borderRadius: BorderRadius.circular(30),
                      border: border),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: _Thumb(video, width: 54, height: 36),
                    ),
                    const SizedBox(width: 8),
                    const Text('Watch together',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            )
          : Container(
              key: const ValueKey('card'),
              width: 240,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                  color: const Color(0xFF000000),
                  borderRadius: BorderRadius.circular(16),
                  border: border),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onWatch,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Stack(children: [
                      _Thumb(video, width: 240, height: 132),
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Semantics(
                          button: true,
                          label: 'Hide',
                          child: GestureDetector(
                            onTap: onClose,
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.close,
                                  size: 15, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ]),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(video.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            Row(children: [
                              Expanded(
                                child: Text(video.site,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: AppColors.textFaint,
                                        fontSize: 11)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                    color: AppColors.lilac,
                                    borderRadius: BorderRadius.circular(10)),
                                child: const Text('Watch together',
                                    style: TextStyle(
                                        color: Color(0xFFFFFFFF),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700)),
                              ),
                            ]),
                          ]),
                    ),
                  ]),
                ),
              ),
            ),
    );
  }
}

/// Two or more videos on the page: a tray of thumbnails at the bottom.
/// Tap one to watch it; Select (or a long-press) ticks several.
class BrowserVideoTray extends StatefulWidget {
  final List<FoundVideo> videos;
  final bool inRoom;
  final void Function(List<FoundVideo> picked) onPick;
  const BrowserVideoTray(
      {super.key,
      required this.videos,
      required this.inRoom,
      required this.onPick});

  @override
  State<BrowserVideoTray> createState() => _BrowserVideoTrayState();
}

class _BrowserVideoTrayState extends State<BrowserVideoTray> {
  bool _selecting = false;
  final _ticked = <String>{};

  List<FoundVideo> get _playable =>
      widget.videos.where((v) => !v.locked).toList();

  String _action(int n) => widget.inRoom
      ? 'Add $n to queue'
      : n == 1
          ? 'Start watch party'
          : 'Start watch party with $n';

  void _toggle(FoundVideo v) {
    if (v.locked) return;
    setState(() =>
        _ticked.contains(v.key) ? _ticked.remove(v.key) : _ticked.add(v.key));
  }

  void _selectAll() => setState(() {
        final all = _playable.map((v) => v.key).toSet();
        if (_ticked.containsAll(all)) {
          _ticked.clear();
        } else {
          _ticked.addAll(all);
        }
      });

  void _submit() {
    final picked = widget.videos.where((v) => _ticked.contains(v.key)).toList();
    if (picked.isEmpty) return;
    widget.onPick(picked);
  }

  Future<void> _seeAll() async {
    final result = await showModalBottomSheet<List<FoundVideo>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF000000),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _SeeAllSheet(
          videos: widget.videos, initial: _ticked, action: _action),
    );
    if (result != null && result.isNotEmpty) widget.onPick(result);
  }

  @override
  void didUpdateWidget(covariant BrowserVideoTray old) {
    super.didUpdateWidget(old);
    final keys = widget.videos.map((v) => v.key).toSet();
    _ticked.removeWhere((k) => !keys.contains(k));
  }

  @override
  Widget build(BuildContext context) {
    final n = _ticked.length;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: const BoxDecoration(
        color: Color(0xFF000000),
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Expanded(
              child: Text(
                  _selecting
                      ? (n == 0 ? 'Tap videos to pick' : '$n selected')
                      : '${widget.videos.length} videos on this page',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ),
            if (_selecting) ...[
              _chip('Select all', _selectAll),
              TextButton(
                onPressed: () => setState(() {
                  _selecting = false;
                  _ticked.clear();
                }),
                child: const Text('Cancel'),
              ),
            ] else ...[
              _chip('Select', () => setState(() => _selecting = true)),
              TextButton(onPressed: _seeAll, child: const Text('See all')),
            ],
          ]),
          const SizedBox(height: 6),
          SizedBox(
            height: 70,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: widget.videos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final v = widget.videos[i];
                return Semantics(
                  button: true,
                  label: v.locked ? '${v.title}, protected' : v.title,
                  child: GestureDetector(
                    onTap: () {
                      if (_selecting) {
                        _toggle(v);
                      } else if (!v.locked) {
                        widget.onPick([v]);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text(
                                'This site doesn’t allow playing this video in other apps.')));
                      }
                    },
                    onLongPress: v.locked
                        ? null
                        : () => setState(() {
                              _selecting = true;
                              _ticked.add(v.key);
                            }),
                    child: Opacity(
                      opacity: v.locked ? 0.5 : 1,
                      child: _Thumb(v,
                          width: 120,
                          height: 70,
                          ticked: _selecting ? _ticked.contains(v.key) : null),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_selecting && n > 0) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.lilac,
                    foregroundColor: const Color(0xFFFFFFFF),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                child: Text(_action(n)),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _chip(String label, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(left: 6),
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            visualDensity: VisualDensity.compact,
            side: const BorderSide(color: Colors.white24),
            shape: const StadiumBorder(),
          ),
          child: Text(label, style: const TextStyle(fontSize: 12)),
        ),
      );
}

/// Every video on the page with tick boxes and Select all.
class _SeeAllSheet extends StatefulWidget {
  final List<FoundVideo> videos;
  final Set<String> initial;
  final String Function(int n) action;
  const _SeeAllSheet(
      {required this.videos, required this.initial, required this.action});

  @override
  State<_SeeAllSheet> createState() => _SeeAllSheetState();
}

class _SeeAllSheetState extends State<_SeeAllSheet> {
  late final _ticked = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    final playable = widget.videos.where((v) => !v.locked).toList();
    final allTicked =
        playable.isNotEmpty && _ticked.containsAll(playable.map((v) => v.key));
    final n = _ticked.length;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      builder: (_, scroll) => Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 4),
          child: Row(children: [
            const Expanded(
              child: Text('Videos on this page',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
            ),
            IconButton(
              tooltip: 'Close',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, color: Colors.white),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(children: [
            Expanded(
              child: Text('$n of ${playable.length} selected',
                  style: const TextStyle(
                      color: AppColors.textFaint, fontSize: 12)),
            ),
            OutlinedButton(
              onPressed: () => setState(() {
                if (allTicked) {
                  _ticked.clear();
                } else {
                  _ticked.addAll(playable.map((v) => v.key));
                }
              }),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.lilac,
                side: const BorderSide(color: AppColors.lilac),
                shape: const StadiumBorder(),
                visualDensity: VisualDensity.compact,
              ),
              child: Text(allTicked ? 'Clear all' : 'Select all'),
            ),
          ]),
        ),
        Expanded(
          child: ListView.separated(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            itemCount: widget.videos.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final v = widget.videos[i];
              final on = _ticked.contains(v.key);
              return InkWell(
                onTap: v.locked
                    ? null
                    : () => setState(
                        () => on ? _ticked.remove(v.key) : _ticked.add(v.key)),
                child: Opacity(
                  opacity: v.locked ? 0.5 : 1,
                  child: Row(children: [
                    Icon(
                        v.locked
                            ? Icons.lock_outline
                            : on
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                        color: on ? AppColors.lilac : Colors.white),
                    const SizedBox(width: 10),
                    _Thumb(v, width: 112, height: 64),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(v.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 3),
                            Text(
                                v.locked
                                    ? 'This site doesn’t allow playing it in other apps'
                                    : v.site,
                                style: const TextStyle(
                                    color: AppColors.textFaint, fontSize: 11)),
                          ]),
                    ),
                  ]),
                ),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: n == 0
                      ? null
                      : () => Navigator.pop(
                          context,
                          widget.videos
                              .where((v) => _ticked.contains(v.key))
                              .toList()),
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.lilac,
                      foregroundColor: const Color(0xFFFFFFFF)),
                  child: Text(n == 0 ? 'Pick videos' : widget.action(n)),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
