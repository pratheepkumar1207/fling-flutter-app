import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/active_room_holder.dart';
import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../theme/insync_icons.dart';
import '../../widgets/app_image.dart';
import '../../widgets/gift_bottom_sheet.dart';
import '../../widgets/report_user_sheet.dart';
import '../calls/start_call.dart';
import '../messages/message_thread_screen.dart';
import '../party/party_screen.dart';
import '../profile/creator_profile_screen.dart';
import 'discover_sheets.dart';
import 'discover_ui.dart';
import '../../widgets/insync_snack.dart';

/// Long-press on someone (map, Discover, lists): a card with their details
/// and, when they're in a lobby they let you see, that lobby with Join or
/// Ask to join. Tap outside to close; swipe up for the full profile.
Future<void> showPeekCard(BuildContext context, String userId) {
  HapticFeedback.mediumImpact();
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.black.withValues(alpha: 0.72),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (_, __, ___) => _PeekCard(userId: userId),
    transitionBuilder: (_, a, __, child) => FadeTransition(
      opacity: a,
      child: ScaleTransition(
          scale: Tween(begin: 0.92, end: 1.0)
              .animate(CurvedAnimation(parent: a, curve: Curves.easeOutBack)),
          child: child),
    ),
  );
}

class _PeekCard extends StatefulWidget {
  final String userId;
  const _PeekCard({required this.userId});
  @override
  State<_PeekCard> createState() => _PeekCardState();
}

class _PeekCardState extends State<_PeekCard> {
  Map<String, dynamic>? _p;
  String? _error;
  bool _askBusy = false;
  bool _inviteBusy = false;
  bool _likeBusy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await ApiClient.get('/discover/peek/${widget.userId}')
          as Map<String, dynamic>;
      if (mounted) setState(() => _p = p);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _error =
            e.status == 404 ? 'This profile isn’t available.' : e.message);
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Couldn’t load this profile.');
    }
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context).showSnackBar(insyncSnackBar(content: Text(text)));
  }

  String get _name => _p?['name'] as String? ?? '';

  void _openProfile() {
    final nav = Navigator.of(context);
    nav.pop();
    nav.push(MaterialPageRoute(
        builder: (_) => CreatorProfileScreen(userId: widget.userId)));
  }

  Future<void> _like() async {
    setState(() => _likeBusy = true);
    try {
      final r = await ApiClient.post('/swipe',
          body: {'toUserId': widget.userId, 'action': 'like'}) as Map;
      if (!mounted) return;
      setState(() => _p!['myAction'] = 'like');
      _toast(
          r['matched'] == true ? 'It’s a match with $_name' : 'Liked $_name');
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.status == 429 && e.data is Map) {
        await showOutOfLikesSheet(context, e.data as Map);
      } else {
        _toast(e.message);
      }
    } catch (_) {
      if (mounted) _toast('Couldn’t like right now.');
    } finally {
      if (mounted) setState(() => _likeBusy = false);
    }
  }

  Future<void> _follow() async {
    final on = _p!['isFollowing'] == true;
    setState(() => _p!['isFollowing'] = !on);
    try {
      await ApiClient.post(
          '/social/${on ? 'unfollow' : 'follow'}/${widget.userId}');
    } catch (_) {
      if (mounted) setState(() => _p!['isFollowing'] = on);
    }
  }

  Future<void> _askToJoin() async {
    setState(() => _askBusy = true);
    try {
      await ApiClient.post('/rooms/ask-join', body: {'userId': widget.userId});
      JoinAsks.mark(widget.userId);
      if (mounted) setState(() {});
    } on ApiException catch (e) {
      if (mounted) _toast(e.message);
    } catch (_) {
      if (mounted) _toast('Couldn’t send the request.');
    } finally {
      if (mounted) setState(() => _askBusy = false);
    }
  }

  Future<void> _invite(String myRoomId) async {
    setState(() => _inviteBusy = true);
    try {
      await ApiClient.post('/rooms/$myRoomId/invite', body: {
        'userIds': [widget.userId]
      });
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(insyncSnackBar(content: Text('Invite sent to $_name')));
    } on ApiException catch (e) {
      if (mounted) _toast(e.message);
    } catch (_) {
      if (mounted) _toast('Couldn’t send the invite.');
    } finally {
      if (mounted) setState(() => _inviteBusy = false);
    }
  }

  void _more() {
    showModalBottomSheet(
      context: context,
      backgroundColor: DColors.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (sheet) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SheetHandle(),
          ListTile(
            leading: const InIcon(InIcons.user, color: Colors.white),
            title: const Text('View full profile'),
            onTap: () {
              Navigator.of(sheet).pop();
              _openProfile();
            },
          ),
          ListTile(
            leading: const InIcon(InIcons.flame, color: DColors.redSoft),
            title:
                const Text('Report', style: TextStyle(color: DColors.redSoft)),
            onTap: () {
              Navigator.of(sheet).pop();
              showReportReasonSheet(context,
                  userName: _name,
                  onSubmit: (reason) async {
                    await ApiClient.post('/social/report/${widget.userId}',
                        body: {'reason': reason});
                  },
                  onAlsoBlock: () =>
                      ApiClient.post('/social/block/${widget.userId}'));
            },
          ),
          ListTile(
            leading: const InIcon(InIcons.block, color: DColors.redSoft),
            title:
                const Text('Block', style: TextStyle(color: DColors.redSoft)),
            onTap: () async {
              Navigator.of(sheet).pop();
              await ApiClient.post('/social/block/${widget.userId}')
                  .catchError((_) => null);
              if (!mounted) return;
              Navigator.of(context).pop();
              _toast('$_name is blocked');
            },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GestureDetector(
            onVerticalDragEnd: (d) {
              if ((d.primaryVelocity ?? 0) < -400 && _p != null) _openProfile();
            },
            child: Material(
              color: DColors.card,
              borderRadius: BorderRadius.circular(26),
              clipBehavior: Clip.antiAlias,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  border: Border.fromBorderSide(BorderSide(color: DColors.line, width: 0.8)),
                ),
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.86,
                    maxWidth: 440),
                child: _p == null
                    ? _loadingOrError()
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(14), child: _body(_p!)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _loadingOrError() {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close')),
        ]),
      );
    }
    return const Padding(
      padding: EdgeInsets.all(14),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              SkeletonBox(width: 56, height: 56, radius: 28),
              SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    SkeletonBox(width: 140, height: 16),
                    SizedBox(height: 8),
                    SkeletonBox(width: 100, height: 12),
                  ])),
            ]),
            SizedBox(height: 16),
            SkeletonBox(height: 12),
            SizedBox(height: 8),
            SkeletonBox(width: 200, height: 12),
            SizedBox(height: 16),
            SkeletonBox(height: 44, radius: 14),
          ]),
    );
  }

  Widget _body(Map<String, dynamic> p) {
    final relation = p['relation'] as String? ?? 'none';
    final close = relation == 'friend' || relation == 'match';
    final room = p['activeRoom'] as Map?;
    final age = p['age'];
    final km = p['distanceKm'];
    final where = [
      if (p['username'] != null) '@${p['username']}',
      if (km != null) close ? '$km km' : 'about $km km away',
      if (p['city'] != null && p['city'].toString().isNotEmpty) p['city'],
    ].join(' · ');
    final inCommon = {
      for (final i in (p['inCommon'] as List? ?? const []))
        i.toString().toLowerCase()
    };
    final interests =
        (p['interests'] as List? ?? const []).map((e) => e.toString()).toList();
    final facts = <(InIconData, String)>[
      if (lookingForLabel(p['lookingFor'] as String?).isNotEmpty)
        (InIcons.heart, lookingForLabel(p['lookingFor'] as String?)),
      if ((p['languages'] as List?)?.isNotEmpty == true)
        (InIcons.lang, (p['languages'] as List).take(3).join(', ')),
      if (heightLabel(p['height'] as int?).isNotEmpty)
        (InIcons.user, heightLabel(p['height'] as int?)),
    ];
    final myRoomId = ActiveRoomHolder.roomId;

    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            PersonFace(
              avatarUrl: p['avatarUrl'] as String?,
              name: _name,
              size: 56,
              ring: room != null
                  ? RingKind.lobby
                  : close
                      ? RingKind.close
                      : RingKind.none,
              online: p['online'] == true,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(
                        child: Text(age != null ? '$_name, $age' : _name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w700)),
                      ),
                      if (p['isVerified'] == true) ...[
                        const SizedBox(width: 4),
                        const InIcon(InIcons.verified,
                            size: 16, color: Colors.white),
                      ],
                    ]),
                    if (where.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(where,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: DColors.dim, fontSize: 12)),
                      ),
                    const SizedBox(height: 6),
                    Wrap(spacing: 5, runSpacing: 5, children: [
                      if (relation == 'match')
                        const DChip('Matched',
                            icon: InIcons.heart, tone: DTone.red, fontSize: 11),
                      if (relation == 'friend')
                        const DChip('Friend',
                            icon: InIcons.users,
                            tone: DTone.white,
                            fontSize: 11),
                      if (p['isVip'] == true)
                        const DChip('VIP',
                            icon: InIcons.crown,
                            tone: DTone.white,
                            fontSize: 11),
                    ]),
                  ]),
            ),
          ]),
          if ((p['bio'] as String?)?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 12),
            Text(p['bio'] as String,
                style: const TextStyle(
                    color: Color(0xFFFFFFFF), fontSize: 13, height: 1.45)),
          ],
          if (facts.isNotEmpty || interests.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final f in facts) DChip(f.$2, icon: f.$1),
              for (final i in interests.take(8))
                DChip(i,
                    tone: inCommon.contains(i.toLowerCase())
                        ? DTone.outline
                        : DTone.plain),
            ]),
          ],
          if (room != null) ...[
            const SizedBox(height: 14),
            _lobbyBox(room),
          ] else if (close && myRoomId != null) ...[
            const SizedBox(height: 14),
            DButton('Invite to my lobby',
                icon: InIcons.send,
                kind: DButtonKind.outline,
                busy: _inviteBusy,
                onPressed: () => _invite(myRoomId)),
          ],
          const SizedBox(height: 14),
          Row(children: [
            if (!close &&
                p['myAction'] != 'like' &&
                p['myAction'] != 'superlike')
              _action(InIcons.heart, 'Like', _likeBusy ? null : _like,
                  primary: true),
            _action(InIcons.chat, 'Message', () {
              final nav = Navigator.of(context);
              nav.pop();
              nav.push(MaterialPageRoute(
                  builder: (_) => MessageThreadScreen(
                      userId: widget.userId,
                      name: _name,
                      avatarUrl: p['avatarUrl'] as String?)));
            }),
            if (close)
              _action(InIcons.phone, 'Call', () {
                final nav = Navigator.of(context);
                nav.pop();
                startDirectCall(nav.context,
                    userId: widget.userId,
                    name: _name,
                    avatarUrl: p['avatarUrl'] as String?,
                    video: false);
              })
            else
              _action(InIcons.useradd,
                  p['isFollowing'] == true ? 'Following' : 'Follow', _follow),
            _action(InIcons.gift, 'Gift',
                () => showGiftBottomSheet(context, toUserId: widget.userId)),
            _action(InIcons.more, 'More', _more),
          ]),
          const SizedBox(height: 4),
          const Center(
              child: Text('Swipe up for the full profile',
                  style: TextStyle(color: Color(0xFFFFFFFF), fontSize: 11))),
        ]);
  }

  Widget _lobbyBox(Map room) {
    final isPrivate = room['isPrivate'] == true;
    final canJoin = room['canJoin'] == true && room['roomId'] != null;
    final canAsk = room['canAsk'] == true;
    final title =
        (room['title'] as String?) ?? (room['nowPlayingTitle'] as String?);
    final watching = room['memberCount'] ?? 0;
    final mics = room['onMicCount'] ?? 0;
    final verb = switch (room['roomType']) {
      'voice' => 'listening',
      'game' => 'playing',
      _ => 'watching'
    };
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: DColors.redTint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DColors.red, width: 0.8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          if (isPrivate)
            const InIcon(InIcons.lock, size: 14, color: DColors.redSoft)
          else
            Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                    color: DColors.red, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(isPrivate ? 'In a private lobby' : 'In a lobby now',
              style: const TextStyle(
                  color: DColors.redSoft,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 8),
        if (isPrivate)
          const Text('The host decides who joins.',
              style: TextStyle(color: DColors.dim, fontSize: 12))
        else
          Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 64,
                height: 40,
                color: DColors.photo,
                alignment: Alignment.center,
                child: room['nowPlayingThumbnail'] != null
                    ? AppImage(
                        source: room['nowPlayingThumbnail'] as String,
                        fit: BoxFit.cover)
                    : const InIcon(InIcons.play, size: 18, color: Colors.white),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title ?? 'A lobby',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    Text(
                        ['$watching $verb', if (mics > 0) '$mics on mic']
                            .join(' · '),
                        style:
                            const TextStyle(color: DColors.dim, fontSize: 12)),
                  ]),
            ),
          ]),
        const SizedBox(height: 10),
        if (canJoin)
          DButton('Join lobby', icon: InIcons.play, onPressed: () {
            final nav = Navigator.of(context);
            nav.pop();
            nav.push(MaterialPageRoute(
                builder: (_) => PartyScreen(roomId: room['roomId'] as String)));
          })
        else if (JoinAsks.askedAt(widget.userId) != null)
          AskedNote(
              userId: widget.userId, busy: _askBusy, onAskAgain: _askToJoin)
        else if (canAsk)
          DButton('Ask to join', busy: _askBusy, onPressed: _askToJoin),
      ]),
    );
  }

  Widget _action(InIconData icon, String label, VoidCallback? onTap,
      {bool primary = false}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Material(
          color: primary ? Colors.white : DColors.chip,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Column(children: [
                InIcon(icon,
                    size: 19,
                    color: primary ? Colors.black : Colors.white,
                    filled: primary && icon == InIcons.heart),
                const SizedBox(height: 3),
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11,
                        color: primary ? Colors.black : Colors.white,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
