import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/profile_nav.dart';
import '../../models/room_models.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_image.dart';
import '../../widgets/glass.dart';

// Deterministic per-user gradient for the initials fallback, matching
// RosterSheetDark.dc.html's colorful avatars — local to this screen, same
// pattern as blocked_accounts_screen.dart.
const _kAvatarGradients = [
  [Color(0xFFC9825A), Color(0xFF5C2E17)],
  [Color(0xFF5A82B8), Color(0xFF1E3A5C)],
  [Color(0xFFB8A25A), Color(0xFF4C4017)],
  [Color(0xFF6BAF8A), Color(0xFF1E4C34)],
  [Color(0xFFA5709A), Color(0xFF4C2447)],
  [Color(0xFFC96B6B), Color(0xFF5C1E1E)],
];

/// The room's participant list — opened as a right-side Drawer (see
/// party_screen.dart's endDrawer + _scaffoldKey.currentState?.openEndDrawer())
/// rather than RosterSheetDark.dc.html's literal bottom sheet — keeping the
/// Drawer presentation avoids touching party_screen's scaffold wiring for a
/// pure layout-position change. Content matches the mockup: colorful
/// gradient avatars, a gold "Host" pill for the real host (the mockup's
/// "Mod" badge on a second row isn't backed by any room-level moderator
/// concept in this app's data model — RosterEntry only has isHost — so it's
/// left out), and a real Follow/Following toggle (GET/POST /social/follow)
/// in place of the old friend-request icon action; friend requests are
/// still reachable from CreatorProfileScreen and Friends' "Find people" tab.
class RosterSheet extends StatefulWidget {
  final List<RosterEntry> roster;
  final String? hostId;
  final bool isHost;
  final String? myUserId;
  final void Function(String userId) onKick;
  final void Function(String userId) onMakeHost;
  final String? roomType;
  final List<String>? activeMics;
  final List<String>? mutedMics;
  final void Function(String userId)? onInviteMic;
  final void Function(String userId)? onForceMute;
  final void Function(String userId)? onForceUnmute;

  const RosterSheet({
    super.key,
    required this.roster,
    required this.hostId,
    required this.isHost,
    required this.myUserId,
    required this.onKick,
    required this.onMakeHost,
    this.roomType,
    this.activeMics,
    this.mutedMics,
    this.onInviteMic,
    this.onForceMute,
    this.onForceUnmute,
  });

  @override
  State<RosterSheet> createState() => _RosterSheetState();
}

class _RosterSheetState extends State<RosterSheet> {
  Set<String> _following = {};
  final Set<String> _pendingFollow = {};

  @override
  void initState() {
    super.initState();
    _loadFollowing();
  }

  Future<void> _loadFollowing() async {
    try {
      final data = await ApiClient.get('/social/following') as List;
      if (!mounted) return;
      setState(() =>
          _following = data.map((u) => (u as Map)['id'] as String).toSet());
    } catch (_) {
      // non-critical — rows just fall back to showing "Follow" for everyone
    }
  }

  Future<void> _toggleFollow(String userId) async {
    final wasFollowing = _following.contains(userId);
    setState(() {
      _pendingFollow.add(userId);
      wasFollowing ? _following.remove(userId) : _following.add(userId);
    });
    try {
      await ApiClient.post(
          '/social/${wasFollowing ? 'unfollow' : 'follow'}/$userId');
    } catch (_) {
      if (mounted) {
        setState(() =>
            wasFollowing ? _following.add(userId) : _following.remove(userId));
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Action failed')));
      }
    } finally {
      if (mounted) setState(() => _pendingFollow.remove(userId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.transparent,
      width: 300,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(left: Radius.circular(24))),
      child: GlassPanel(
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(24)),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                            color: AppColors.text,
                            fontWeight: FontWeight.w700,
                            fontSize: 16),
                        children: [
                          const TextSpan(text: 'In the room '),
                          TextSpan(
                              text: '· ${widget.roster.length} people',
                              style: const TextStyle(
                                  color: AppColors.textFaint,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13)),
                        ],
                      ),
                    ),
                    IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded,
                            color: AppColors.textFaint)),
                  ],
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: ListView.builder(
                    itemCount: widget.roster.length,
                    itemBuilder: (context, i) =>
                        _row(context, widget.roster[i], i),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, RosterEntry r, int index) {
    final isRowHost = r.userId == widget.hostId;
    final isMe = r.userId == widget.myUserId;
    final onStage = widget.activeMics?.contains(r.userId) ?? false;
    final canInviteMic = widget.isHost &&
        widget.roomType == 'voice' &&
        widget.onInviteMic != null &&
        !onStage;
    final isMuted = widget.mutedMics?.contains(r.userId) ?? false;
    final canToggleMute = widget.isHost &&
        widget.roomType == 'voice' &&
        onStage &&
        widget.onForceMute != null &&
        widget.onForceUnmute != null;
    final following = _following.contains(r.userId);
    final pending = _pendingFollow.contains(r.userId);
    final gradient = _kAvatarGradients[index % _kAvatarGradients.length];

    return GestureDetector(
      onTap: () => openProfile(context, r.userId),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: gradient)),
              alignment: Alignment.center,
              child: r.avatarUrl != null
                  ? AppImage(source: r.avatarUrl, fit: BoxFit.cover)
                  : Text(initials(r.name),
                      style: GoogleFonts.bricolageGrotesque(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13)),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text('${r.name}${isMe ? ' (you)' : ''}',
                  style: const TextStyle(
                      color: AppColors.text,
                      fontWeight: FontWeight.w700,
                      fontSize: 13),
                  overflow: TextOverflow.ellipsis),
            ),
            if (isRowHost)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999)),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star_rounded, color: AppColors.gold, size: 11),
                    SizedBox(width: 4),
                    Text('Host',
                        style: TextStyle(
                            color: AppColors.gold,
                            fontWeight: FontWeight.w700,
                            fontSize: 10.5)),
                  ],
                ),
              )
            else if (!isMe)
              GestureDetector(
                onTap: pending ? null : () => _toggleFollow(r.userId),
                child: Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        border:
                            Border.all(color: AppColors.border, width: 1.5)),
                    child: Text(following ? 'Following' : 'Follow',
                        style: const TextStyle(
                            color: AppColors.textDim,
                            fontWeight: FontWeight.w700,
                            fontSize: 11)),
                  ),
                ),
              ),
            if (widget.isHost && !isMe) ...[
              if (canInviteMic)
                IconButton(
                    onPressed: () => widget.onInviteMic!(r.userId),
                    tooltip: 'Invite to mic',
                    icon: const Icon(Icons.mic_rounded,
                        color: AppColors.gold, size: 16),
                    visualDensity: VisualDensity.compact),
              if (canToggleMute)
                TextButton(
                  onPressed: () => isMuted
                      ? widget.onForceUnmute!(r.userId)
                      : widget.onForceMute!(r.userId),
                  child: Text(isMuted ? 'Unmute' : 'Mute',
                      style: TextStyle(
                          color: isMuted ? AppColors.gold : AppColors.textDim,
                          fontSize: 11)),
                ),
              TextButton(
                  onPressed: () => widget.onMakeHost(r.userId),
                  child: const Text('Host',
                      style:
                          TextStyle(color: AppColors.primary, fontSize: 11))),
              TextButton(
                  onPressed: () => widget.onKick(r.userId),
                  child: const Text('Kick',
                      style: TextStyle(color: AppColors.danger, fontSize: 11))),
            ],
          ],
        ),
      ),
    );
  }
}
