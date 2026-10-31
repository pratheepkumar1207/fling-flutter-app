import '../../theme/insync_icons.dart';
import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/room_person_scope.dart';
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
/// party_screen.dart's endDrawer + _scaffoldKey.currentState?.openEndDrawer()).
///
/// Half the screen wide, frosted glass over the room. Compact rows: the host
/// in their own section, everyone else below with their name and a status
/// line (on mic / muted / following). Tap a row for their profile card; the
/// host and co-host long-press for their options, same as on a seat. Search
/// filters by name; Invite sits at the bottom.
class RosterSheet extends StatefulWidget {
  final List<RosterEntry> roster;
  final String? hostId;
  final bool isHost;
  final String? myUserId;
  final String? roomType;
  final List<String>? activeMics;
  final List<String>? mutedMics;
  final VoidCallback? onInvite;
  const RosterSheet({
    super.key,
    required this.roster,
    required this.hostId,
    required this.isHost,
    required this.myUserId,
    this.roomType,
    this.activeMics,
    this.mutedMics,
    this.onInvite,
  });

  @override
  State<RosterSheet> createState() => _RosterSheetState();
}

class _RosterSheetState extends State<RosterSheet> {
  Set<String> _following = {};
  String _query = '';

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
      // non-critical — rows just don't say "Following"
    }
  }

  bool _onMic(RosterEntry r) => widget.activeMics?.contains(r.userId) ?? false;
  bool _muted(RosterEntry r) => widget.mutedMics?.contains(r.userId) ?? false;

  bool _matches(RosterEntry r) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return r.name.toLowerCase().contains(q) ||
        (r.username?.toLowerCase().contains(q) ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final host = widget.roster.where((r) => r.userId == widget.hostId);
    // You first among everyone else, then roster order.
    final others = widget.roster
        .where((r) => r.userId != widget.hostId)
        .toList()
      ..sort((a, b) => (a.userId == widget.myUserId ? 0 : 1)
          .compareTo(b.userId == widget.myUserId ? 0 : 1));
    final shownHost = host.where(_matches).toList();
    final shownOthers = others.where(_matches).toList();
    final othersLabel = widget.roomType == 'voice' ? 'Listening' : 'Watching';
    return Drawer(
      backgroundColor: Colors.transparent,
      width: MediaQuery.sizeOf(context).width * 0.5,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(left: Radius.circular(24))),
      child: GlassPanel(
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(24)),
        tintAlpha: 0.6,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 2, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('In the room',
                              style: TextStyle(
                                  color: AppColors.text,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15)),
                          Text('${widget.roster.length} people',
                              style: const TextStyle(
                                  color: AppColors.textFaint, fontSize: 11.5)),
                        ],
                      ),
                    ),
                    IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const InIcon(InIcons.close,
                            color: AppColors.textFaint, size: 20)),
                  ],
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: TextField(
                    onChanged: (v) => setState(() => _query = v),
                    style: const TextStyle(color: AppColors.text, fontSize: 13),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Search',
                      hintStyle: const TextStyle(
                          color: AppColors.textFaint, fontSize: 13),
                      prefixIcon: const InIcon(InIcons.search,
                          color: AppColors.textFaint, size: 18),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      filled: true,
                      fillColor: AppColors.surface2.withValues(alpha: 0.6),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    children: [
                      if (shownHost.isNotEmpty) ...[
                        _sectionLabel('Host'),
                        for (final r in shownHost) _row(context, r),
                      ],
                      if (shownOthers.isNotEmpty) ...[
                        _sectionLabel('$othersLabel · ${others.length}'),
                        for (final r in shownOthers) _row(context, r),
                      ],
                      if (shownHost.isEmpty && shownOthers.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 24),
                          child: Center(
                            child: Text('Nobody here by that name.',
                                style: TextStyle(
                                    color: AppColors.textFaint, fontSize: 13)),
                          ),
                        ),
                    ],
                  ),
                ),
                if (widget.onInvite != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, right: 10),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          widget.onInvite!();
                        },
                        icon: const InIcon(InIcons.useradd, size: 18),
                        label: const Text('Invite'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.accent,
                          side: const BorderSide(color: AppColors.border),
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 4),
        child: Text(text,
            style: const TextStyle(
                color: AppColors.textFaint,
                fontSize: 11.5,
                fontWeight: FontWeight.w600)),
      );

  Widget _avatar(RosterEntry r) {
    final index = widget.roster.indexWhere((e) => e.userId == r.userId);
    final gradient =
        _kAvatarGradients[(index < 0 ? 0 : index) % _kAvatarGradients.length];
    return Container(
      width: 32,
      height: 32,
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
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 11.5)),
    );
  }

  Widget _row(BuildContext context, RosterEntry r) =>
      Builder(builder: (row) => _rowBody(row, r));

  Widget _rowBody(BuildContext context, RosterEntry r) {
    final isRowHost = r.userId == widget.hostId;
    final isMe = r.userId == widget.myUserId;
    final onMic = _onMic(r);
    final muted = _muted(r);
    final following = _following.contains(r.userId);
    final status = [
      if (isRowHost) 'Host',
      if (onMic) muted ? 'Muted' : 'On mic',
      if (!isRowHost && !isMe && following) 'Following',
    ];
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => openRoomPerson(context, r.userId),
      onLongPress: () => longPressRoomPerson(context, r.userId),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            _avatar(r),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${r.name}${isMe ? ' (you)' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.text,
                          fontWeight: FontWeight.w700,
                          fontSize: 13)),
                  if (status.isNotEmpty)
                    Row(
                      children: [
                        if (isRowHost)
                          const Padding(
                            padding: EdgeInsets.only(right: 3),
                            child: InIcon(InIcons.crown,
                                color: AppColors.gold, size: 12),
                          )
                        else if (onMic)
                          Padding(
                            padding: const EdgeInsets.only(right: 3),
                            child: InIcon(muted ? InIcons.micoff : InIcons.mic,
                                color: muted
                                    ? AppColors.textFaint
                                    : AppColors.success,
                                size: 12),
                          ),
                        Flexible(
                          child: Text(status.join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: isRowHost
                                      ? AppColors.gold
                                      : AppColors.textFaint,
                                  fontSize: 11.5)),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
