import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/format.dart';
import '../../models/user.dart';
import '../../theme/insync_icons.dart';
import '../../widgets/app_image.dart';
import '../../widgets/report_user_sheet.dart';
import '../party/party_screen.dart';
import 'discover_ui.dart';

/// Tap a Discover card: the whole profile, then Pass or Like. Returns
/// 'pass' / 'like' when one was chosen.
Future<String?> showDiscoverProfile(BuildContext context, DiscoverProfile p) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.black,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      maxChildSize: 0.96,
      minChildSize: 0.5,
      builder: (context, scroll) => _ProfileBody(p: p, scroll: scroll),
    ),
  );
}

class _ProfileBody extends StatefulWidget {
  final DiscoverProfile p;
  final ScrollController scroll;
  const _ProfileBody({required this.p, required this.scroll});
  @override
  State<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends State<_ProfileBody> {
  Future<void> _ask() async {
    try {
      await ApiClient.post('/rooms/ask-join', body: {'userId': widget.p.id});
      JoinAsks.mark(widget.p.id);
      if (mounted) setState(() {});
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final common = {for (final i in p.inCommon) i.toLowerCase()};
    final facts = [
      if (heightLabel(p.height).isNotEmpty)
        (InIcons.user, heightLabel(p.height)),
      if (p.languages.isNotEmpty)
        (InIcons.lang, p.languages.take(3).join(', ')),
      if (lookingForLabel(p.lookingFor).isNotEmpty)
        (InIcons.heart, lookingForLabel(p.lookingFor)),
      if (p.religion != null && p.religion!.isNotEmpty)
        (InIcons.spark, p.religion!),
    ];
    final room = p.activeRoom;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
        child: Row(children: [
          IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const InIcon(InIcons.down, color: Colors.white)),
          Expanded(
            child: Text(p.age != null ? '${p.name}, ${p.age}' : p.name,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
      Expanded(
        child: ListView(
            controller: widget.scroll,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: AspectRatio(
                  aspectRatio: 4 / 5,
                  child: p.avatarUrl != null
                      ? AppImage(source: p.avatarUrl, fit: BoxFit.cover)
                      : Container(
                          color: DColors.photo,
                          alignment: Alignment.center,
                          child: Text(initials(p.name),
                              style: const TextStyle(
                                  fontSize: 60,
                                  color: Color(0xFFFFFFFF),
                                  fontWeight: FontWeight.w800)),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Row(children: [
                if (p.isVerified) ...[
                  const InIcon(InIcons.verified, size: 16, color: Colors.white),
                  const SizedBox(width: 4),
                  const Text('Verified', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 10),
                ],
                if (p.distanceKm != null || (p.city?.isNotEmpty ?? false)) ...[
                  const InIcon(InIcons.pin, size: 14, color: DColors.dim),
                  const SizedBox(width: 3),
                  Text(
                      [
                        if (p.distanceKm != null) '${p.distanceKm} km',
                        if (p.city?.isNotEmpty ?? false) p.city!
                      ].join(' · '),
                      style: const TextStyle(color: DColors.dim, fontSize: 12)),
                ],
              ]),
              if (p.bio?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 10),
                Text(p.bio!,
                    style: const TextStyle(
                        color: Color(0xFFFFFFFF), fontSize: 14, height: 1.5)),
              ],
              if (facts.isNotEmpty) ...[
                const DLabel('About'),
                Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [for (final f in facts) DChip(f.$2, icon: f.$1)]),
              ],
              if (p.interests.isNotEmpty) ...[
                DLabel(p.inCommon.isNotEmpty
                    ? 'Interests · red ones you both like'
                    : 'Interests'),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final i in p.interests)
                    DChip(i,
                        tone: common.contains(i.toLowerCase())
                            ? DTone.outline
                            : DTone.plain),
                ]),
              ],
              if (room != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: DColors.redTint,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: DColors.red, width: 0.8),
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                            room['isPrivate'] == true
                                ? 'In a private lobby'
                                : 'In a lobby now',
                            style: const TextStyle(
                                color: DColors.redSoft,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        if (room['isPrivate'] != true)
                          Text(
                              '${room['title'] ?? 'A lobby'} · ${room['memberCount'] ?? 0} in it',
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 10),
                        if (room['roomId'] != null)
                          DButton('Join lobby', icon: InIcons.play,
                              onPressed: () {
                            Navigator.of(context).pop();
                            Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => PartyScreen(
                                    roomId: room['roomId'] as String)));
                          })
                        else if (JoinAsks.askedAt(widget.p.id) != null)
                          AskedNote(userId: widget.p.id, onAskAgain: _ask)
                        else
                          DButton('Ask to join', onPressed: _ask),
                      ]),
                ),
              ],
              const SizedBox(height: 18),
              Center(
                child: TextButton(
                  onPressed: () => showReportUserSheet(
                    context,
                    userName: p.name,
                    onReport: () => showReportReasonSheet(context,
                        userName: p.name,
                        onSubmit: (reason) => ApiClient.post(
                            '/social/report/${p.id}',
                            body: {'reason': reason}),
                        onAlsoBlock: () =>
                            ApiClient.post('/social/block/${p.id}')),
                    onBlock: () async {
                      await ApiClient.post('/social/block/${p.id}')
                          .catchError((_) => null);
                      if (context.mounted) Navigator.of(context).pop('pass');
                    },
                  ),
                  child: const Text('Report · Block',
                      style: TextStyle(color: DColors.dim)),
                ),
              ),
            ]),
      ),
      SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
          child: Row(children: [
            Expanded(
                child: DButton('Pass',
                    kind: DButtonKind.ghost,
                    onPressed: () => Navigator.of(context).pop('pass'))),
            const SizedBox(width: 10),
            Expanded(
                child: DButton('Like',
                    icon: InIcons.heart,
                    onPressed: () => Navigator.of(context).pop('like'))),
          ]),
        ),
      ),
    ]);
  }
}
