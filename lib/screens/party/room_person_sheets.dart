import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/profile_nav.dart';
import '../../core/room_person_scope.dart';
import '../../models/room_models.dart';
import '../../theme/app_colors.dart';
import '../../widgets/avatar.dart';
import '../../widgets/verified_tick.dart';
import '../messages/message_thread_screen.dart';

// ---------------------------------------------------------------- long press

enum PersonAction {
  inviteToSpeak('Invite to speak'),
  invitePlay('Invite to play'),
  mute('Mute'),
  unmute('Unmute'),
  makeCoHost('Make co-host'),
  removeCoHost('Remove co-host'),
  moveToListeners('Move to listeners'),
  remove('Remove'),
  ban('Ban');

  final String label;
  const PersonAction(this.label);

  bool get isDanger => this == remove || this == ban;
}

/// What a long press offers. The host gets everything; a co-host only runs
/// mics and removes people; nobody can act on the host or themselves, and
/// everyone else gets no popup at all.
List<PersonAction> personActions({
  required bool iAmHost,
  required bool iAmCoHost,
  required bool iOwnRoom,
  required bool isSelf,
  required bool targetIsHost,
  required bool targetIsCoHost,
  required bool voice,
  required bool onStage,
  required bool muted,
  bool canInvitePlay = false,
}) {
  if ((!iAmHost && !iAmCoHost) || isSelf || targetIsHost) return const [];
  return [
    if (canInvitePlay) PersonAction.invitePlay,
    if (voice && onStage) muted ? PersonAction.unmute : PersonAction.mute,
    if (voice && !onStage && !targetIsCoHost) PersonAction.inviteToSpeak,
    if (iAmHost)
      targetIsCoHost ? PersonAction.removeCoHost : PersonAction.makeCoHost,
    if (voice && onStage && !targetIsCoHost) PersonAction.moveToListeners,
    PersonAction.remove,
    // Bans cover all the owner's rooms, so someone only keeping the seat warm
    // can't place them.
    if (iOwnRoom) PersonAction.ban,
  ];
}

/// The popup beside a seat: the room dims, that person stays lit up.
Future<PersonAction?> showPersonActionsPopup(
  BuildContext context, {
  required RosterEntry person,
  required Rect anchor,
  required List<PersonAction> actions,
}) {
  HapticFeedback.mediumImpact();
  return showGeneralDialog<PersonAction>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.black.withValues(alpha: 0.6),
    transitionDuration: const Duration(milliseconds: 140),
    transitionBuilder: (_, a, __, child) => FadeTransition(
        opacity: a,
        child: ScaleTransition(
            scale: Tween(begin: 0.96, end: 1.0).animate(a), child: child)),
    pageBuilder: (dialog, _, __) {
      final screen = MediaQuery.sizeOf(dialog);
      final pad = MediaQuery.paddingOf(dialog);
      const width = 210.0;
      final itemHeight = 46.0 * MediaQuery.textScalerOf(dialog).scale(1);
      final height = itemHeight * actions.length + 8;
      final left =
          (anchor.center.dx - width / 2).clamp(12.0, screen.width - width - 12);
      final below = anchor.bottom + 8 + height < screen.height - pad.bottom;
      final top = below
          ? anchor.bottom + 8
          : (anchor.top - 8 - height).clamp(pad.top + 8, screen.height);
      return Stack(children: [
        Positioned.fromRect(
          rect: anchor,
          child: IgnorePointer(
            child: FittedBox(
              child: Avatar(
                  src: person.avatarUrl,
                  name: person.name,
                  size: AvatarSize.lg),
            ),
          ),
        ),
        Positioned(
          left: left,
          top: top,
          width: width,
          child: Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints:
                  BoxConstraints(maxHeight: screen.height - pad.vertical - 16),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  for (final a in actions)
                    InkWell(
                      onTap: () => Navigator.of(dialog).pop(a),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 46),
                        width: double.infinity,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(a.label,
                            style: TextStyle(
                                color: a.isDanger
                                    ? AppColors.danger
                                    : AppColors.text,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                ]),
              ),
            ),
          ),
        ),
      ]);
    },
  );
}

/// Remove and Ban ask first; true means go ahead.
Future<bool> confirmPersonAction(
    BuildContext context, PersonAction action, String name) async {
  final first = name.split(' ').first;
  final ban = action == PersonAction.ban;
  final ok = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(ban ? 'Ban $first?' : 'Remove $first from this room?'),
      content: Text(ban
          ? 'They can’t join any of your rooms.'
          : 'They can join again later.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(d).pop(false),
            child: const Text('Cancel')),
        TextButton(
            onPressed: () => Navigator.of(d).pop(true),
            child: Text(ban ? 'Ban' : 'Remove',
                style: const TextStyle(color: AppColors.danger))),
      ],
    ),
  );
  return ok == true;
}

// ---------------------------------------------------------------- profile card

/// Tapping a person in a room: their profile slides up, and you stay in the
/// room. The same card for everyone in every room type.
Future<void> showRoomPersonCard(
  BuildContext context, {
  required RosterEntry person,
  required bool isMe,
  required String status,
  required VoidCallback onMessage,
  @visibleForTesting Map<String, dynamic>? initialProfile,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (sheet) => _PersonCard(
      person: person,
      isMe: isMe,
      status: status,
      initialProfile: initialProfile,
      onMessage: () {
        Navigator.of(sheet).pop();
        onMessage();
      },
      onFullProfile: () {
        Navigator.of(sheet).pop();
        openProfile(context, person.userId);
      },
    ),
  );
}

class _PersonCard extends StatefulWidget {
  final RosterEntry person;
  final bool isMe;
  final String status;
  final Map<String, dynamic>? initialProfile;
  final VoidCallback onMessage;
  final VoidCallback onFullProfile;

  const _PersonCard({
    required this.person,
    required this.isMe,
    required this.status,
    this.initialProfile,
    required this.onMessage,
    required this.onFullProfile,
  });

  @override
  State<_PersonCard> createState() => _PersonCardState();
}

class _PersonCardState extends State<_PersonCard> {
  Map<String, dynamic>? _p;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _p = widget.initialProfile;
    if (_p == null) _load();
  }

  Future<void> _load() async {
    try {
      final data =
          await ApiClient.get('/creators/${widget.person.userId}/profile');
      if (mounted) setState(() => _p = Map<String, dynamic>.from(data as Map));
    } catch (_) {
      // The card still shows the name and picture from the room.
    }
  }

  Future<void> _act(Future<void> Function() call) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await call();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Action failed')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addFriend() => _act(() async {
        await ApiClient.post('/friends/request',
            body: {'toUserId': widget.person.userId});
        if (mounted) setState(() => _p!['friendStatus'] = 'pending_sent');
      });

  Future<void> _accept() => _act(() async {
        await ApiClient.post('/friends/${_p!['friendRequestId']}/accept');
        if (mounted) setState(() => _p!['friendStatus'] = 'friends');
      });

  Future<void> _toggleFollow() => _act(() async {
        final following = _p!['isFollowedByMe'] == true;
        await ApiClient.post(
            '/social/${following ? 'unfollow' : 'follow'}/${widget.person.userId}');
        if (mounted) {
          setState(() {
            _p!['isFollowedByMe'] = !following;
            _p!['followerCount'] =
                ((_p!['followerCount'] as num?) ?? 0) + (following ? -1 : 1);
          });
        }
      });

  Widget _stat(String label, Object? value) => Expanded(
        child: Column(children: [
          Text(formatNumber(value ?? 0),
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          Text(label,
              style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
        ]),
      );

  String? _followedByLine() {
    final f = _p?['followedBy'];
    if (f is! Map) return null;
    final names = (f['names'] as List? ?? []).cast<String>();
    if (names.isEmpty) return null;
    final others =
        ((f['count'] as num?) ?? names.length).toInt() - names.length;
    return 'Followed by ${names.join(', ')}'
        '${others > 0 ? ' and $others other${others == 1 ? '' : 's'}' : ''}';
  }

  List<Widget> _buttons() {
    final first = widget.person.name.split(' ').first;
    final friend = _p?['friendStatus'] as String? ?? 'none';
    final following = _p?['isFollowedByMe'] == true;
    final Widget primary = switch (friend) {
      'friends' =>
        FilledButton(onPressed: widget.onMessage, child: const Text('Message')),
      'pending_sent' =>
        const OutlinedButton(onPressed: null, child: Text('Requested')),
      'pending_received' => FilledButton(
          onPressed: _busy ? null : _accept, child: const Text('Accept')),
      _ => FilledButton(
          onPressed: _busy ? null : _addFriend,
          child: const Text('Add friend')),
    };
    return [
      Row(children: [
        Expanded(child: primary),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton(
            onPressed: _busy ? null : _toggleFollow,
            child: Text(following ? 'Following' : 'Follow'),
          ),
        ),
      ]),
      if (friend == 'pending_sent')
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('You can message $first once you’re friends',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
        ),
      const SizedBox(height: 8),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    final username = (p?['username'] as String?) ?? widget.person.username;
    final bio = (p?['bio'] as String?)?.trim();
    final followed = _followedByLine();
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Avatar(
                  src: widget.person.avatarUrl,
                  name: widget.person.name,
                  size: AvatarSize.lg),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Flexible(
                          child: Text(widget.person.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.w700)),
                        ),
                        if (p?['isVerified'] == true) ...[
                          const SizedBox(width: 4),
                          const VerifiedTick(),
                        ],
                      ]),
                      Text(
                          [
                            if (username != null) '@$username',
                            widget.status,
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.textDim, fontSize: 12.5)),
                    ]),
              ),
            ]),
            if (bio != null && bio.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(bio,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13.5, height: 1.35)),
            ],
            const SizedBox(height: 14),
            Row(children: [
              _stat('Posts', p?['postCount']),
              _stat('Followers', p?['followerCount']),
              _stat('Following', p?['followingCount']),
            ]),
            if (followed != null) ...[
              const SizedBox(height: 10),
              Text(followed,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(color: AppColors.textDim, fontSize: 12)),
            ],
            const SizedBox(height: 14),
            if (!widget.isMe && p != null) ..._buttons(),
            TextButton(
                onPressed: widget.onFullProfile,
                child: const Text('View full profile')),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- listeners

/// "7 listening ›": everyone not on a seat. Host and co-host can bring them
/// up from here; everyone else just sees who's listening.
Future<void> showListenersSheet(
  BuildContext context, {
  required Listenable changes,
  required List<RosterEntry> Function() listeners,
  required List<String> Function() pending,
  required bool Function() canModerate,
  required String? myUserId,
  required void Function(String userId) onInvite,
  required void Function(String userId) onAllow,
}) {
  final scope = RoomPersonScope.maybeOf(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (sheet) => ConstrainedBox(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(sheet).height * 0.7),
      child: AnimatedBuilder(
        animation: changes,
        builder: (sheet, _) {
          final people = listeners();
          final asking = pending();
          final mod = canModerate();
          final list = SafeArea(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('${people.length} listening',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
              if (people.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 28),
                  child: Text('Nobody’s listening yet.',
                      style: TextStyle(color: AppColors.textDim)),
                ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: people.length,
                  itemBuilder: (_, i) {
                    final r = people[i];
                    final wants = asking.contains(r.userId);
                    return Builder(
                      builder: (row) => ListTile(
                        onTap: () => openRoomPerson(row, r.userId),
                        onLongPress: () => longPressRoomPerson(row, r.userId),
                        leading: Avatar(
                            src: r.avatarUrl,
                            name: r.name,
                            size: AvatarSize.md),
                        title: Text(
                            '${r.name}${r.userId == myUserId ? ' (you)' : ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14)),
                        subtitle: wants
                            ? const Text('Wants to speak',
                                style: TextStyle(
                                    color: AppColors.lilac, fontSize: 12))
                            : null,
                        trailing: mod && r.userId != myUserId
                            ? wants
                                ? FilledButton(
                                    onPressed: () => onAllow(r.userId),
                                    child: const Text('Allow'))
                                : OutlinedButton(
                                    onPressed: () => onInvite(r.userId),
                                    child: const Text('Invite'))
                            : null,
                      ),
                    );
                  },
                ),
              ),
            ]),
          );
          return scope == null
              ? list
              : RoomPersonScope(
                  onTap: scope.onTap,
                  onLongPress: scope.onLongPress,
                  child: list);
        },
      ),
    ),
  );
}

// ---------------------------------------------------------------- direct message

/// Message from inside a room: the same conversation as Messages, on a sheet
/// over two-thirds of the screen. The room's audio and mic keep running.
Future<void> showRoomDmSheet(
  BuildContext context, {
  required String userId,
  required String name,
  String? avatarUrl,
  required String roomTitle,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black38,
    builder: (sheet) {
      final media = MediaQuery.of(sheet);
      final keyboard = media.viewInsets.bottom;
      final height = (media.size.height * 0.66)
          .clamp(0.0, media.size.height - keyboard - media.padding.top - 12);
      return Padding(
        padding: EdgeInsets.only(bottom: keyboard),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          child: SizedBox(
            height: height,
            child: MediaQuery.removeViewInsets(
              context: sheet,
              removeBottom: true,
              child: MessageThreadScreen(
                userId: userId,
                name: name,
                avatarUrl: avatarUrl,
                inRoomSheet: true,
                onExpand: () {
                  Navigator.of(sheet).pop();
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => MessageThreadScreen(
                          userId: userId,
                          name: name,
                          avatarUrl: avatarUrl,
                          backToRoomTitle: roomTitle)));
                },
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// A new message while you're in the room: their picture with the count,
/// above the chat box. Tap to open it; hold to dismiss.
class RoomDmBubble extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final int count;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const RoomDmBubble({
    super.key,
    required this.name,
    this.avatarUrl,
    required this.count,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$count new message${count == 1 ? '' : 's'} from $name',
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onDismiss,
        child: SizedBox.square(
          dimension: 52,
          child: Stack(clipBehavior: Clip.none, children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: AppColors.lilac),
              child: FittedBox(
                  child:
                      Avatar(src: avatarUrl, name: name, size: AvatarSize.lg)),
            ),
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                constraints: const BoxConstraints(minWidth: 20),
                height: 20,
                padding: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                    color: AppColors.danger,
                    borderRadius: BorderRadius.circular(999)),
                alignment: Alignment.center,
                child: Text(count > 99 ? '99+' : '$count',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
