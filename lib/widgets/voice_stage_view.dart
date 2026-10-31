import '../theme/insync_icons.dart';
import 'package:flutter/material.dart';
import '../core/room_person_scope.dart';
import '../models/room_models.dart';
import '../theme/app_colors.dart';
import '../theme/vola_party_colors.dart';
import 'avatar.dart';
import 'in_icon_button.dart';
import '../theme/room_themes.dart';

/// Who sits where: the host in seat 1, the co-host in seat 2 (both even with
/// their mics off), then everyone else on stage in the order they came up.
List<String> voiceSeatOrder({
  required Iterable<String> inRoom,
  required String? hostId,
  required String? coHostId,
  required List<String> activeMics,
}) {
  final here = inRoom.toSet();
  return [
    if (hostId != null && here.contains(hostId)) hostId,
    if (coHostId != null && coHostId != hostId && here.contains(coHostId))
      coHostId,
    for (final id in activeMics)
      if (id != hostId && id != coHostId && here.contains(id)) id,
  ];
}

/// The Voice room stage: "You're hosting" for the host, requests to speak,
/// four seats to a row, and the listening count that opens the list.
class VoiceStageView extends StatefulWidget {
  final List<RosterEntry> roster;
  final List<String> activeMics;
  final List<String> pendingRequests;
  final List<String> mutedMics;
  final Set<String> speaking;
  final int maxSlots;
  final String? hostId;
  final String? coHostId;
  final String? myUserId;
  final bool myMicRequested;
  final void Function(String userId) onApprove;
  final void Function(String userId) onDeny;
  final VoidCallback onOpenListeners;
  final VoidCallback onAskToSpeak;
  final VoidCallback? onSettings;

  const VoiceStageView({
    super.key,
    required this.roster,
    required this.activeMics,
    required this.pendingRequests,
    this.mutedMics = const [],
    this.speaking = const {},
    required this.maxSlots,
    required this.hostId,
    this.coHostId,
    required this.myUserId,
    this.myMicRequested = false,
    required this.onApprove,
    required this.onDeny,
    required this.onOpenListeners,
    required this.onAskToSpeak,
    this.onSettings,
  });

  @override
  State<VoiceStageView> createState() => _VoiceStageViewState();
}

class _VoiceStageViewState extends State<VoiceStageView> {
  bool _noteClosed = false;

  bool get _iAmHost =>
      widget.myUserId != null && widget.myUserId == widget.hostId;
  bool get _iAmCoHost =>
      !_iAmHost &&
      widget.myUserId != null &&
      widget.myUserId == widget.coHostId;
  bool get _canModerate => _iAmHost || _iAmCoHost;

  @override
  Widget build(BuildContext context) {
    final byId = {for (final r in widget.roster) r.userId: r};
    final seats = voiceSeatOrder(
        inRoom: byId.keys,
        hostId: widget.hostId,
        coHostId: widget.coHostId,
        activeMics: widget.activeMics);
    final listening = widget.roster.length - seats.length;
    final hostName = byId[widget.hostId]?.name.split(' ').first ?? 'The host';
    final firstRequest = widget.pendingRequests
        .where(byId.containsKey)
        .cast<String?>()
        .firstWhere((_) => true, orElse: () => null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_canModerate) ...[
          Row(children: [
            Expanded(
              child: Text(_iAmHost ? 'You’re hosting' : 'You’re a co-host',
                  style: const TextStyle(
                      color: VolaPartyColors.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ),
            if (_iAmHost && widget.onSettings != null)
              InIconButton(InIcons.gear,
                  tooltip: 'Room settings',
                  color: VolaPartyColors.textDim,
                  onPressed: widget.onSettings),
          ]),
          const SizedBox(height: 6),
        ],
        if (_iAmCoHost && !_noteClosed)
          _note(
              '$hostName made you a co-host. You can approve mics and help run the room.'),
        if (_canModerate && firstRequest != null)
          _requestCard(context, firstRequest, byId[firstRequest]!),
        LayoutBuilder(builder: (context, constraints) {
          const gap = 8.0;
          final seat = (constraints.maxWidth - gap * 3) / 4;
          final circle = (seat - 10).clamp(40.0, 72.0);
          final onStage = seats.contains(widget.myUserId);
          return Wrap(
            spacing: gap,
            runSpacing: 14,
            children: List.generate(widget.maxSlots, (i) {
              if (i < seats.length) {
                final uid = seats[i];
                return SizedBox(
                  width: seat,
                  child: _PersonSeat(
                    person: byId[uid]!,
                    size: circle,
                    isMe: uid == widget.myUserId,
                    isHost: uid == widget.hostId,
                    isCoHost: uid == widget.coHostId,
                    talking: widget.speaking.contains(uid) &&
                        !widget.mutedMics.contains(uid),
                    muted: widget.mutedMics.contains(uid) ||
                        !widget.activeMics.contains(uid),
                  ),
                );
              }
              // The first free seat invites you up; the rest are just empty.
              final isFirstFree = i == seats.length;
              final String label;
              final VoidCallback? onTap;
              if (_canModerate) {
                label = 'Invite';
                onTap = widget.onOpenListeners;
              } else if (isFirstFree && !onStage) {
                label = widget.myMicRequested ? 'Asked' : 'Ask to speak';
                onTap = widget.onAskToSpeak;
              } else {
                label = 'Empty';
                onTap = null;
              }
              return SizedBox(
                width: seat,
                child: _EmptySeat(
                    size: circle,
                    label: label,
                    showPlus: onTap != null,
                    onTap: onTap),
              );
            }),
          );
        }),
        const SizedBox(height: 10),
        Semantics(
          button: true,
          label: '$listening listening, open the list',
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: widget.onOpenListeners,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const InIcon(InIcons.users,
                    size: 15, color: VolaPartyColors.textDim),
                const SizedBox(width: 6),
                Text('$listening listening',
                    style: const TextStyle(
                        color: VolaPartyColors.textDim,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600)),
                const SizedBox(width: 2),
                const InIcon(InIcons.right,
                    size: 13, color: VolaPartyColors.textFaint),
              ]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _note(String text) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        decoration: BoxDecoration(
          color: AppColors.lilac.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          const InIcon(InIcons.shield, size: 15, color: AppColors.lilac),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: VolaPartyColors.text, fontSize: 12, height: 1.3)),
          ),
          InIconButton(InIcons.close,
              tooltip: 'Close',
              size: 15,
              color: VolaPartyColors.textFaint,
              onPressed: () => setState(() => _noteClosed = true)),
        ]),
      );

  Widget _requestCard(BuildContext context, String uid, RosterEntry person) {
    final primary = RoomTheme.of(context).primary;
    final waiting = widget.pendingRequests.length;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: primary.withValues(alpha: 0.3)),
      ),
      child: LayoutBuilder(builder: (context, box) {
        final who = Row(children: [
          GestureDetector(
            onTap: () => openRoomPerson(context, uid),
            child: Avatar(
                src: person.avatarUrl, name: person.name, size: AvatarSize.sm),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
                '${person.name.split(' ').first} wants to speak'
                '${waiting > 1 ? ' · $waiting waiting' : ''}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: VolaPartyColors.text,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600)),
          ),
        ]);
        final buttons = Row(mainAxisSize: MainAxisSize.min, children: [
          TextButton(
            onPressed: () => widget.onDeny(uid),
            style: TextButton.styleFrom(
                foregroundColor: VolaPartyColors.textDim,
                visualDensity: VisualDensity.compact,
                minimumSize: const Size(44, 36)),
            child: const Text('Not now', style: TextStyle(fontSize: 12)),
          ),
          FilledButton(
            onPressed: () => widget.onApprove(uid),
            style: FilledButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                visualDensity: VisualDensity.compact,
                minimumSize: const Size(44, 36)),
            child: const Text('Allow',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ]);
        // Buttons drop to their own line on a small phone or with big text.
        final tight =
            box.maxWidth / MediaQuery.textScalerOf(context).scale(1) < 330;
        return tight
            ? Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                who,
                const SizedBox(height: 4),
                buttons,
              ])
            : Row(children: [Expanded(child: who), buttons]);
      }),
    );
  }
}

class _PersonSeat extends StatelessWidget {
  final RosterEntry person;
  final double size;
  final bool isMe;
  final bool isHost;
  final bool isCoHost;
  final bool talking;
  final bool muted;

  const _PersonSeat({
    required this.person,
    required this.size,
    required this.isMe,
    required this.isHost,
    required this.isCoHost,
    required this.talking,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    final roleColor = isHost
        ? VolaPartyColors.gold
        : isCoHost
            ? AppColors.lilac
            : null;
    final ring =
        talking ? AppColors.success : roleColor ?? RoomTheme.of(context).border;
    final badge = (size * 0.34).clamp(16.0, 24.0);
    return Semantics(
      button: true,
      label: [
        person.name,
        if (isHost) 'host',
        if (isCoHost) 'co-host',
        if (talking) 'talking',
        if (muted) 'mic off',
      ].join(', '),
      child: Builder(
        builder: (seatContext) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => openRoomPerson(seatContext, person.userId),
          onLongPress: () => longPressRoomPerson(seatContext, person.userId),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox.square(
              dimension: size + badge / 3,
              child: Stack(alignment: Alignment.topCenter, children: [
                Container(
                  width: size,
                  height: size,
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: ring, width: 2.5),
                  ),
                  child: FittedBox(
                    child: Avatar(
                        src: person.avatarUrl,
                        name: person.name,
                        size: AvatarSize.lg),
                  ),
                ),
                if (roleColor != null)
                  Positioned(
                    bottom: 0,
                    child: Container(
                      width: badge,
                      height: badge,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: roleColor,
                        border: Border.all(
                            color: RoomTheme.of(context).surface, width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: InIcon(isHost ? InIcons.crown : InIcons.shield,
                          size: badge * 0.6,
                          color: isHost
                              ? const Color(0xFF3A2A00)
                              : const Color(0xFF241338)),
                    ),
                  ),
                if (muted)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: RoomTheme.of(context).surface,
                      ),
                      alignment: Alignment.center,
                      child: const InIcon(InIcons.micoff,
                          size: 11, color: VolaPartyColors.textFaint),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 4),
            Text(isMe ? 'You' : person.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: VolaPartyColors.text,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}

class _EmptySeat extends StatelessWidget {
  final double size;
  final String label;
  final bool showPlus;
  final VoidCallback? onTap;

  const _EmptySeat(
      {required this.size,
      required this.label,
      required this.showPlus,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: RoomTheme.of(context).border, width: 1.5),
          ),
          alignment: Alignment.center,
          child: showPlus
              ? const InIcon(InIcons.plus,
                  color: VolaPartyColors.textDim, size: 20)
              : null,
        ),
        SizedBox(height: 4 + (size * 0.34).clamp(16.0, 24.0) / 3),
        Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: showPlus
                    ? VolaPartyColors.textDim
                    : VolaPartyColors.textFaint,
                fontSize: 11)),
      ]),
    );
  }
}

/// While typing, the seats shrink to one line so chat gets the screen.
class VoiceTypingRow extends StatelessWidget {
  final List<RosterEntry> onStage;
  final String? talkingName;
  final int listening;

  const VoiceTypingRow({
    super.key,
    required this.onStage,
    required this.talkingName,
    required this.listening,
  });

  @override
  Widget build(BuildContext context) {
    final shown = onStage.take(4).toList();
    return Row(children: [
      SizedBox(
        width: shown.isEmpty ? 0 : 28.0 + (shown.length - 1) * 18,
        height: 28,
        child: Stack(children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * 18.0,
              child: SizedBox.square(
                dimension: 28,
                child: FittedBox(
                  child: Avatar(
                      src: shown[i].avatarUrl,
                      name: shown[i].name,
                      size: AvatarSize.sm),
                ),
              ),
            ),
        ]),
      ),
      if (shown.isNotEmpty) const SizedBox(width: 8),
      Expanded(
        child: Text(
            [
              if (talkingName != null) '$talkingName is talking',
              '$listening listening',
            ].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: VolaPartyColors.textDim, fontSize: 12.5)),
      ),
    ]);
  }
}
