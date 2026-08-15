import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/profile_nav.dart';
import '../../models/room_models.dart';
import '../../theme/app_colors.dart';
import '../../widgets/avatar.dart';

/// The room's participant list — opened as a right-side Drawer (see
/// party_screen.dart's endDrawer + _scaffoldKey.currentState?.openEndDrawer())
/// rather than a bottom sheet, so it reads like Discord's member list.
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
  // userId -> {'status': 'none'|'pending_sent'|'pending_received'|'friends', 'requestId': String?}
  Map<String, Map<String, dynamic>> _friendStatuses = {};

  @override
  void initState() {
    super.initState();
    _loadFriendStatuses();
  }

  Future<void> _loadFriendStatuses() async {
    final otherIds = widget.roster.where((r) => r.userId != widget.myUserId).map((r) => r.userId).toList();
    if (otherIds.isEmpty) return;
    try {
      final data = await ApiClient.post('/friends/status', body: {'userIds': otherIds}) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _friendStatuses = data.map((k, v) => MapEntry(k, Map<String, dynamic>.from(v as Map)));
      });
    } catch (_) {
      // non-critical — rows just fall back to showing no friend icon
    }
  }

  Future<void> _sendFriendRequest(String userId) async {
    setState(() => _friendStatuses[userId] = {'status': 'pending_sent'});
    try {
      await ApiClient.post('/friends/request', body: {'toUserId': userId});
    } catch (_) {
      if (mounted) {
        setState(() => _friendStatuses[userId] = {'status': 'none'});
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to send friend request')));
      }
    }
  }

  Future<void> _acceptFriendRequest(String userId, String requestId) async {
    setState(() => _friendStatuses[userId] = {'status': 'friends'});
    try {
      await ApiClient.post('/friends/$requestId/accept');
    } catch (_) {
      if (mounted) {
        setState(() => _friendStatuses[userId] = {'status': 'pending_received', 'requestId': requestId});
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to accept friend request')));
      }
    }
  }

  Widget? _friendAction(String userId) {
    final friend = _friendStatuses[userId];
    final status = friend?['status'] as String?;
    if (status == null || status == 'friends') return null;
    if (status == 'pending_sent') {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 6),
        child: Text('⏳', style: TextStyle(fontSize: 13)),
      );
    }
    if (status == 'pending_received') {
      return TextButton(
        onPressed: () => _acceptFriendRequest(userId, friend!['requestId'] as String),
        child: const Text('Accept', style: TextStyle(color: AppColors.primary, fontSize: 12)),
      );
    }
    return IconButton(
      onPressed: () => _sendFriendRequest(userId),
      tooltip: 'Add friend',
      icon: const Text('👤➕', style: TextStyle(fontSize: 14)),
      visualDensity: VisualDensity.compact,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.surface2,
      width: 300,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('In this room', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold, fontSize: 16)),
                  IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close, color: AppColors.textFaint)),
                ],
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: widget.roster.length,
                  itemBuilder: (context, i) {
                    final r = widget.roster[i];
                    final isRowHost = r.userId == widget.hostId;
                    final isMe = r.userId == widget.myUserId;
                    final onStage = widget.activeMics?.contains(r.userId) ?? false;
                    final canInviteMic = widget.isHost && widget.roomType == 'voice' && widget.onInviteMic != null && !onStage;
                    final isMuted = widget.mutedMics?.contains(r.userId) ?? false;
                    final canToggleMute = widget.isHost && widget.roomType == 'voice' && onStage && widget.onForceMute != null && widget.onForceUnmute != null;
                    final friendAction = isMe ? null : _friendAction(r.userId);
                    return ListTile(
                      onTap: () => openProfile(context, r.userId),
                      leading: Avatar(src: r.avatarUrl, name: r.name, size: AvatarSize.sm),
                      title: Text('${r.name}${isRowHost ? ' 👑' : ''}${isMe ? ' (you)' : ''}', style: const TextStyle(color: AppColors.text), overflow: TextOverflow.ellipsis),
                      trailing: isMe
                          ? null
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (friendAction != null) friendAction,
                                if (widget.isHost) ...[
                                  if (canInviteMic)
                                    TextButton(onPressed: () => widget.onInviteMic!(r.userId), child: const Text('🎙️', style: TextStyle(color: AppColors.gold, fontSize: 14))),
                                  if (canToggleMute)
                                    TextButton(
                                      onPressed: () => isMuted ? widget.onForceUnmute!(r.userId) : widget.onForceMute!(r.userId),
                                      child: Text(isMuted ? 'Unmute' : 'Mute', style: TextStyle(color: isMuted ? AppColors.gold : AppColors.textDim, fontSize: 12)),
                                    ),
                                  TextButton(onPressed: () => widget.onMakeHost(r.userId), child: const Text('Host', style: TextStyle(color: AppColors.primary, fontSize: 12))),
                                  TextButton(onPressed: () => widget.onKick(r.userId), child: const Text('Kick', style: TextStyle(color: AppColors.danger, fontSize: 12))),
                                ],
                              ],
                            ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
