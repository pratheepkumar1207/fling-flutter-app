import '../../theme/insync_icons.dart';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../widgets/avatar.dart';
import '../../widgets/insync_clay.dart';

class RoomDiscoveryHeader extends StatelessWidget {
  final String firstName;
  final VoidCallback onCreate, onJoin, onSearch;
  const RoomDiscoveryHeader(
      {super.key,
      required this.firstName,
      required this.onCreate,
      required this.onJoin,
      required this.onSearch});
  @override
  Widget build(BuildContext context) {
    final large = MediaQuery.textScalerOf(context).scale(14) > 20;
    final copy =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('YOUR CREW. YOUR VIBE.',
          style: TextStyle(
              color: AppColors.accent,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1)),
      const SizedBox(height: 12),
      const Text('Life’s better\nin sync.',
          style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              height: 1.06,
              letterSpacing: -1,
              fontWeight: FontWeight.w800)),
      const SizedBox(height: 12),
      const Text('Watch. Talk. Just hang.',
          style: TextStyle(color: Color(0xFFE1E9FF), fontSize: 12)),
      const SizedBox(height: 18),
      FilledButton(
          onPressed: onCreate,
          style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.ink,
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16))),
          child: const Text('Start a room',
              style: TextStyle(fontWeight: FontWeight.w800))),
    ]);
    final art = ExcludeSemantics(
        child: Image.asset('assets/icons/app/watch_clay.png',
            fit: BoxFit.contain));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
              onTap: onSearch,
              borderRadius: BorderRadius.circular(18),
              child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(children: [
                    InIcon(InIcons.search, color: AppColors.textDim),
                    SizedBox(width: 10),
                    Expanded(
                        child: Text('Find your people',
                            style: TextStyle(color: AppColors.textDim))),
                    InIcon(InIcons.chev, size: 18, color: AppColors.textDim)
                  ])))),
      const SizedBox(height: 20),
      Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 24, 12, 22),
          decoration: insyncClay(cobalt: true),
          child: large
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [copy, SizedBox(height: 150, child: art)])
              : Row(children: [
                  Expanded(flex: 6, child: copy),
                  Expanded(flex: 5, child: art)
                ])),
      const SizedBox(height: 10),
      Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            Text('Got an invite, $firstName?',
                style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
            TextButton(
                onPressed: onJoin,
                style: TextButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    minimumSize: const Size(48, 48)),
                child: const Text('Join with code'))
          ]),
    ]);
  }
}

class DiscoveryRoomCard extends StatelessWidget {
  final String title, subtitle, kind;
  final String? imageUrl, gameType;
  final int count;
  final double? positionSeconds;
  final bool isPlaying;
  final List<Map<String, dynamic>> participants;
  final Widget? image;
  final VoidCallback onTap;
  const DiscoveryRoomCard(
      {super.key,
      required this.title,
      required this.subtitle,
      this.imageUrl,
      required this.kind,
      required this.count,
      this.image,
      this.gameType,
      this.positionSeconds,
      this.isPlaying = false,
      this.participants = const [],
      required this.onTap});

  String get timestamp {
    final seconds = positionSeconds!.isFinite
        ? positionSeconds!.clamp(0, 359999).floor()
        : 0;
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remainder = (seconds % 60).toString().padLeft(2, '0');
    return '${isPlaying ? 'Playing' : 'Paused'} · $minutes:$remainder';
  }

  @override
  Widget build(BuildContext context) {
    final watch = kind == 'watch';
    final gameLabel = switch (gameType) {
      'chess' => 'Chess',
      'ludo' => 'Ludo',
      'uno' => 'UNO',
      'tictactoe' => 'Tic-tac-toe',
      'truth_or_dare' => 'Truth or dare',
      'would_you_rather' => 'Would you rather',
      _ => 'Game',
    };
    final art = kind == 'game' && ['chess', 'ludo', 'uno'].contains(gameType)
        ? 'assets/icons/rooms/$gameType.png'
        : 'assets/icons/rooms/voice_lobby.png';
    final preview = watch
        ? image ??
            const Center(
                child: InIcon(InIcons.film, size: 38, color: AppColors.textDim))
        : Stack(alignment: Alignment.center, children: [
            Padding(
                padding: const EdgeInsets.all(12),
                child: kind == 'game' &&
                        !['chess', 'ludo', 'uno'].contains(gameType)
                    ? InIcon(
                        switch (gameType) {
                          'tictactoe' => InIcons.dice,
                          'truth_or_dare' => InIcons.chat,
                          'would_you_rather' => InIcons.swap,
                          _ => InIcons.game
                        },
                        size: 46,
                        color: AppColors.accent)
                    : Image.asset(art, fit: BoxFit.contain)),
            if (kind == 'game')
              const Positioned(
                  bottom: 4,
                  right: 4,
                  child: CircleAvatar(
                      radius: 13,
                      backgroundColor: AppColors.accent,
                      child:
                          InIcon(InIcons.mic, color: AppColors.ink, size: 17))),
          ]);
    final details =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (!watch) ...[
        Text(kind == 'game' ? '$gameLabel · Voice lobby' : 'Voice lobby',
            style: const TextStyle(
                color: AppColors.accent,
                fontSize: 11,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 7),
      ],
      Text(title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              color: AppColors.text,
              fontSize: 16,
              fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),
      Wrap(
          spacing: 5,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final member in participants.take(5))
              Tooltip(
                  message: member['name'] as String? ?? 'Participant',
                  child: Avatar(
                      src: member['avatarUrl'] as String?,
                      name: member['name'] as String?,
                      size: AvatarSize.sm)),
            if (count > participants.take(5).length && participants.isNotEmpty)
              Text('+${count - participants.take(5).length}',
                  style:
                      const TextStyle(color: AppColors.textDim, fontSize: 12)),
          ]),
      const SizedBox(height: 6),
      Text('$count ${count == 1 ? 'person' : 'people'} in the room',
          style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
    ]);
    return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: DecoratedBox(
            decoration: insyncClay(radius: 22),
            child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(22),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                    onTap: onTap,
                    child: watch
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                                AspectRatio(
                                    aspectRatio: 16 / 9,
                                    child:
                                        Stack(fit: StackFit.expand, children: [
                                      ColoredBox(
                                          color: AppColors.surface,
                                          child: preview),
                                      if (positionSeconds != null)
                                        Positioned(
                                            bottom: 10,
                                            right: 10,
                                            child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 6),
                                                decoration: BoxDecoration(
                                                    color: Colors.black87,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            9)),
                                                child: Text(timestamp,
                                                    style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 12)))),
                                    ])),
                                Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: details),
                              ])
                        : Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(children: [
                              Container(
                                  width: 88,
                                  height: 98,
                                  decoration:
                                      insyncClay(cobalt: true, radius: 18),
                                  child: preview),
                              const SizedBox(width: 14),
                              Expanded(child: details),
                            ]))))));
  }
}
