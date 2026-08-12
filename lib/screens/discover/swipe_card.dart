import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/auth_provider.dart';
import '../../core/format.dart';
import '../../models/photo.dart';
import '../../models/user.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_image.dart';
import '../messages/message_thread_screen.dart';

const _kThreshold = 120.0;
const _kTapMaxMovement = 8.0;

/// Flutter port of src/components/SwipeCard.jsx — same two-face flip
/// (photo front, pink-bordered detail back), same tap-vs-drag
/// disambiguation, same VIP-gated "Subscriber Exclusive" styling.
class SwipeCard extends StatefulWidget {
  final DiscoverProfile profile;
  final void Function(String action) onSwipe;
  final bool active;

  const SwipeCard({super.key, required this.profile, required this.onSwipe, required this.active});

  @override
  State<SwipeCard> createState() => _SwipeCardState();
}

class _SwipeCardState extends State<SwipeCard> with SingleTickerProviderStateMixin {
  Offset _drag = Offset.zero;
  bool _dragging = false;
  bool _flipped = false;
  List<Photo>? _gallery;

  void _loadGalleryIfNeeded() {
    if (!_flipped || _gallery != null) return;
    ApiClient.get('/gallery/user/${widget.profile.id}').then((data) {
      if (!mounted) return;
      setState(() {
        _gallery = (data as List).map((e) => Photo.fromJson(e as Map<String, dynamic>)).toList();
      });
    }).catchError((_) {
      if (mounted) setState(() => _gallery = []);
    });
  }

  void _onPanStart(DragStartDetails details) {
    if (!widget.active) return;
    setState(() {
      _dragging = true;
      _drag = Offset.zero;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_dragging) return;
    setState(() => _drag += details.delta);
  }

  void _onPanEnd(DragEndDetails details) {
    if (!_dragging) return;
    final barelyMoved = _drag.dx.abs() < _kTapMaxMovement && _drag.dy.abs() < _kTapMaxMovement;
    if (_drag.dx > _kThreshold) {
      widget.onSwipe('like');
    } else if (_drag.dx < -_kThreshold) {
      widget.onSwipe('pass');
    } else if (_drag.dy < -_kThreshold) {
      widget.onSwipe('superlike');
    } else if (barelyMoved) {
      setState(() => _flipped = !_flipped);
      _loadGalleryIfNeeded();
    }
    setState(() {
      _dragging = false;
      _drag = Offset.zero;
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final rotate = _drag.dx / 18 * (3.14159 / 180);
    final likeOpacity = (_drag.dx / _kThreshold).clamp(0.0, 1.0);
    final passOpacity = (-_drag.dx / _kThreshold).clamp(0.0, 1.0);

    Widget card = AnimatedContainer(
      duration: _dragging ? Duration.zero : const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      transform: widget.active
          ? (Matrix4.identity()
            ..translateByDouble(_drag.dx, _drag.dy, 0.0, 1.0)
            ..rotateZ(rotate))
          : Matrix4.identity(),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: _flipped ? 3.14159 : 0),
        duration: const Duration(milliseconds: 500),
        builder: (context, angle, child) {
          final showFront = angle < 3.14159 / 2;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()..setEntry(3, 2, 0.001)..rotateY(angle),
            child: showFront
                ? _frontFace(profile, likeOpacity, passOpacity)
                : Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(3.14159),
                    child: _backFace(context, profile),
                  ),
          );
        },
      ),
    );

    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: card,
    );
  }

  Widget _frontFace(DiscoverProfile profile, double likeOpacity, double passOpacity) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(color: AppColors.surface2, border: Border.all(color: AppColors.border)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            profile.avatarUrl != null
                ? AppImage(source: profile.avatarUrl, fit: BoxFit.cover)
                : Container(color: AppColors.surface3, alignment: Alignment.center, child: Text(initials(profile.name), style: const TextStyle(color: AppColors.textFaint, fontSize: 56, fontWeight: FontWeight.bold))),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withValues(alpha: 0.85), Colors.black.withValues(alpha: 0.1), Colors.transparent],
                ),
              ),
            ),
            if (likeOpacity > 0)
              Positioned(
                top: 32,
                left: 32,
                child: Opacity(
                  opacity: likeOpacity,
                  child: Transform.rotate(
                    angle: -0.3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(border: Border.all(color: AppColors.success, width: 4), borderRadius: BorderRadius.circular(8)),
                      child: const Text('LIKE', style: TextStyle(color: AppColors.success, fontSize: 24, fontWeight: FontWeight.w900)),
                    ),
                  ),
                ),
              ),
            if (passOpacity > 0)
              Positioned(
                top: 32,
                right: 32,
                child: Opacity(
                  opacity: passOpacity,
                  child: Transform.rotate(
                    angle: 0.3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(border: Border.all(color: AppColors.danger, width: 4), borderRadius: BorderRadius.circular(8)),
                      child: const Text('NOPE', style: TextStyle(color: AppColors.danger, fontSize: 24, fontWeight: FontWeight.w900)),
                    ),
                  ),
                ),
              ),
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(999)),
                child: const Text('🔄 Tap to Flip', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${profile.name}${profile.age != null ? ', ${profile.age}' : ''}',
                          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        if (profile.online) ...[
                          const SizedBox(width: 8),
                          Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle)),
                        ],
                      ],
                    ),
                    if (profile.city != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('📍 ${profile.city}', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
                      ),
                    if (profile.bio != null && profile.bio!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          profile.bio!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13),
                        ),
                      ),
                    if (profile.interests.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: profile.interests.take(4).map((i) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(999)),
                            child: Text(i, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                          )).toList(),
                        ),
                      ),
                    if (profile.sharedInterests > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text('${profile.sharedInterests} shared interests', style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _backFace(BuildContext context, DiscoverProfile profile) {
    final isViewerVip = context.watch<AuthProvider>().user?.isVip ?? false;
    final gallery = _gallery;
    final hasNoDetails = (profile.bio == null || profile.bio!.isEmpty) &&
        profile.city == null &&
        profile.interests.isEmpty &&
        gallery != null &&
        gallery.isEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface2,
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.7), width: 2),
        ),
        padding: const EdgeInsets.all(20),
        child: Stack(
          children: [
            if (isViewerVip)
              Positioned(
                top: 0,
                left: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text('✨ Subscriber Exclusive', style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ),
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3), shape: BoxShape.circle),
                child: const Text('🔄', style: TextStyle(fontSize: 14)),
              ),
            ),
            Column(
              children: [
                const SizedBox(height: 36),
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.primary, width: 4)),
                  clipBehavior: Clip.antiAlias,
                  child: profile.avatarUrl != null
                      ? AppImage(source: profile.avatarUrl, fit: BoxFit.cover)
                      : Container(color: AppColors.surface3, alignment: Alignment.center, child: Text(initials(profile.name), style: const TextStyle(color: AppColors.textFaint, fontSize: 24, fontWeight: FontWeight.bold))),
                ),
                const SizedBox(height: 10),
                Text('${profile.name}${profile.age != null ? ', ${profile.age}' : ''}', style: const TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.bold)),
                if (profile.username != null) Text('@${profile.username}', style: const TextStyle(color: AppColors.textFaint, fontSize: 13)),
                if (profile.city != null)
                  Padding(padding: const EdgeInsets.only(top: 4), child: Text('📍 ${profile.city}', style: const TextStyle(color: AppColors.textDim, fontSize: 13))),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        if (profile.bio != null && profile.bio!.isNotEmpty)
                          Padding(padding: const EdgeInsets.only(top: 12), child: Text(profile.bio!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textDim, fontSize: 13))),
                        if (profile.interests.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 6,
                              runSpacing: 6,
                              children: profile.interests.map((i) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(999)),
                                child: Text(i, style: const TextStyle(color: AppColors.text, fontSize: 11, fontWeight: FontWeight.w600)),
                              )).toList(),
                            ),
                          ),
                        if (gallery != null && gallery.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 6, mainAxisSpacing: 6),
                              itemCount: gallery.length,
                              itemBuilder: (context, i) => ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: AppImage(source: gallery[i].imageData, fit: BoxFit.cover),
                              ),
                            ),
                          ),
                        if (hasNoDetails) const Padding(padding: EdgeInsets.only(top: 16), child: Text('✨\nNo additional details yet', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textFaint))),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => MessageThreadScreen(userId: profile.id, name: profile.name, avatarUrl: profile.avatarUrl)),
                      ),
                      child: Text(isViewerVip ? '➤  Subscriber Direct Message  💬' : '➤  Message  💬'),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text('TAP TO FLIP BACK', style: TextStyle(color: AppColors.textFaint, fontSize: 9, letterSpacing: 1)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
