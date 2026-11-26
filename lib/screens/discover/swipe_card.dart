import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../models/photo.dart';
import '../../models/user.dart';
import '../../theme/insync_icons.dart';
import '../../widgets/app_image.dart';
import 'discover_ui.dart';

const _kThreshold = 110.0;
const _kTapMaxMovement = 8.0;

/// A Discover card, full-photo style: the photo fills the card and the
/// details sit on a dark strip at the bottom. Drag right = like, left =
/// nope, up = super like. Tap the left or right edge of the photo for the
/// previous or next photo, the middle to open the profile; long-press for
/// the quick card.
class SwipeCard extends StatefulWidget {
  final DiscoverProfile profile;
  final void Function(String action) onSwipe;
  final bool active;
  final VoidCallback? onOpen;
  final VoidCallback? onLongPress;
  final VoidCallback? onJoinLobby;

  const SwipeCard({
    super.key,
    required this.profile,
    required this.onSwipe,
    required this.active,
    this.onOpen,
    this.onLongPress,
    this.onJoinLobby,
  });

  @override
  State<SwipeCard> createState() => _SwipeCardState();
}

class _SwipeCardState extends State<SwipeCard> {
  Offset _drag = Offset.zero;
  bool _dragging = false;
  List<String> _photos = const [];
  int _photo = 0;

  @override
  void initState() {
    super.initState();
    _photos = [if (widget.profile.avatarUrl != null) widget.profile.avatarUrl!];
    if (widget.active) _loadGallery();
  }

  @override
  void didUpdateWidget(covariant SwipeCard old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _loadGallery();
  }

  bool _galleryAsked = false;
  void _loadGallery() {
    if (_galleryAsked) return;
    _galleryAsked = true;
    ApiClient.get('/gallery/user/${widget.profile.id}').then((data) {
      if (!mounted || data is! List) return;
      final extra = data
          .map((e) => Photo.fromJson(e as Map<String, dynamic>).imageData)
          .where((s) => s.isNotEmpty && s != widget.profile.avatarUrl)
          .take(5);
      setState(() => _photos = [..._photos, ...extra]);
    }).catchError((_) {});
  }

  void _onPanStart(DragStartDetails d) {
    if (!widget.active) return;
    setState(() {
      _dragging = true;
      _drag = Offset.zero;
    });
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (!_dragging) return;
    setState(() => _drag += d.delta);
  }

  void _onPanEnd(DragEndDetails d) {
    if (!_dragging) return;
    final barelyMoved =
        _drag.dx.abs() < _kTapMaxMovement && _drag.dy.abs() < _kTapMaxMovement;
    final v = d.velocity.pixelsPerSecond;
    if (_drag.dx > _kThreshold || v.dx > 900) {
      widget.onSwipe('like');
    } else if (_drag.dx < -_kThreshold || v.dx < -900) {
      widget.onSwipe('pass');
    } else if (!barelyMoved && (_drag.dy < -_kThreshold || v.dy < -900)) {
      widget.onSwipe('superlike');
    }
    // Taps are handled by onTapUp: a pan only starts past the touch slop.
    setState(() {
      _dragging = false;
      _drag = Offset.zero;
    });
  }

  void _tapAt(Offset at) {
    final width = context.size?.width ?? 1;
    if (_photos.length > 1 && at.dx < width * 0.3) {
      setState(() => _photo = (_photo - 1).clamp(0, _photos.length - 1));
    } else if (_photos.length > 1 && at.dx > width * 0.7) {
      setState(() => _photo = (_photo + 1).clamp(0, _photos.length - 1));
    } else {
      widget.onOpen?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final rotate = _drag.dx / 18 * (3.14159 / 180);
    final like = (_drag.dx / _kThreshold).clamp(0.0, 1.0);
    final nope = (-_drag.dx / _kThreshold).clamp(0.0, 1.0);
    final superLike =
        (-_drag.dy / _kThreshold).clamp(0.0, 1.0) * (1 - like) * (1 - nope);

    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      onTapUp: widget.active ? (d) => _tapAt(d.localPosition) : null,
      onLongPress: widget.active ? widget.onLongPress : null,
      child: AnimatedContainer(
        duration: _dragging ? Duration.zero : const Duration(milliseconds: 320),
        curve: Curves.easeOut,
        transform: widget.active
            ? (Matrix4.identity()
              ..translateByDouble(_drag.dx, _drag.dy, 0.0, 1.0)
              ..rotateZ(rotate))
            : Matrix4.identity(),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            color: DColors.photo,
            child: Stack(fit: StackFit.expand, children: [
              _photoLayer(),
              // Bottom fade so the details read on any photo.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.center,
                    colors: [Color(0xF2000000), Color(0x00000000)],
                  ),
                ),
              ),
              if (_photos.length > 1)
                Positioned(
                  top: 8,
                  left: 10,
                  right: 10,
                  child: Row(children: [
                    for (var i = 0; i < _photos.length; i++)
                      Expanded(
                        child: Container(
                          height: 3,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: i == _photo
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                  ]),
                ),
              Positioned(top: 20, left: 12, child: _badges()),
              if (like > 0)
                _stamp('LIKE', Colors.white, like, left: 22, angle: -0.22),
              if (nope > 0)
                _stamp('NOPE', DColors.red, nope, right: 22, angle: 0.22),
              if (superLike > 0.05)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 150,
                  child: Opacity(
                    opacity: superLike,
                    child: Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const InIcon(InIcons.star,
                            size: 46, color: DColors.red, filled: true),
                        const SizedBox(height: 6),
                        _stampBox('SUPER LIKE', DColors.red),
                      ]),
                    ),
                  ),
                ),
              Positioned(left: 0, right: 0, bottom: 0, child: _details()),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _photoLayer() {
    final p = widget.profile;
    if (_photos.isEmpty) {
      return Container(
        color: const Color(0xFF1F1F1F),
        alignment: Alignment.center,
        child: Text(initials(p.name),
            style: const TextStyle(
                color: Color(0xFF555555),
                fontSize: 64,
                fontWeight: FontWeight.w800)),
      );
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 160),
      child: AppImage(
          key: ValueKey(_photo),
          source: _photos[_photo.clamp(0, _photos.length - 1)],
          fit: BoxFit.cover),
    );
  }

  Widget _badges() {
    final p = widget.profile;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      if (p.online)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
              color: Colors.black, borderRadius: BorderRadius.circular(999)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle)),
            const SizedBox(width: 5),
            const Text('Online',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          ]),
        ),
    ]);
  }

  Widget _stampBox(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          border: Border.all(color: color, width: 3),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(text,
            style: TextStyle(
                color: color,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: 1)),
      );

  Widget _stamp(String text, Color color, double opacity,
      {double? left, double? right, required double angle}) {
    return Positioned(
      top: 54,
      left: left,
      right: right,
      child: Opacity(
          opacity: opacity,
          child: Transform.rotate(angle: angle, child: _stampBox(text, color))),
    );
  }

  Widget _details() {
    final p = widget.profile;
    final where = [
      if (p.distanceKm != null) '${p.distanceKm} km',
      if (p.city != null && p.city!.isNotEmpty) p.city!,
    ].join(' · ');
    final common = {for (final i in p.inCommon) i.toLowerCase()};
    final chips = [
      ...p.interests.where((i) => !common.contains(i.toLowerCase())).take(2),
    ];
    final room = p.activeRoom;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Flexible(
                child: Text(p.age != null ? '${p.name}, ${p.age}' : p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.w800)),
              ),
              if (p.isVerified) ...[
                const SizedBox(width: 6),
                const InIcon(InIcons.verified, size: 20, color: Colors.white),
              ],
            ]),
            if (where.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(children: [
                  const InIcon(InIcons.pin, size: 13, color: DColors.dim),
                  const SizedBox(width: 3),
                  Text(where,
                      style: const TextStyle(
                          color: Color(0xFFBBBBBB), fontSize: 13)),
                ]),
              ),
            if (chips.isNotEmpty || p.inCommon.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final c in chips) DChip(c),
                if (p.inCommon.isNotEmpty)
                  DChip('${p.inCommon.length} in common', tone: DTone.outline),
              ]),
            ],
            if (room != null) ...[
              const SizedBox(height: 9),
              GestureDetector(
                onTap: room['roomId'] != null
                    ? widget.onJoinLobby
                    : widget.onLongPress,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: DColors.redTint,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: DColors.red, width: 0.8),
                  ),
                  child: Row(children: [
                    Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                            color: DColors.red, shape: BoxShape.circle)),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                          room['isPrivate'] == true
                              ? 'In a private lobby'
                              : 'In a lobby · ${room['title'] ?? ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                    Text(room['roomId'] != null ? 'Join' : 'Ask',
                        style: const TextStyle(
                            color: DColors.redSoft,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ],
          ]),
    );
  }
}
