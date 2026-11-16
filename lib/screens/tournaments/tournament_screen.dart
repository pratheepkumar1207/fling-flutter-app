import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/auth_provider.dart';
import '../../core/socket_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/insync_icons.dart';
import '../../widgets/avatar.dart';
import '../../widgets/share_bottom_sheet.dart';
import '../party/party_screen.dart';
import '../wallet/vip_store_screen.dart';
import 'tournament_live.dart';
import 'tournament_watch.dart';

const _purple = Color(0xFF534AB7);
const _purpleLine = Color(0xFF7F77DD);
const _gold = Color(0xFFFAC775);
const _goldLine = Color(0xFFBA7517);
const _goldBg = Color(0xFF412402);

/// Opens a tournament screen with a route name the match strip can find.
Future<void> openTournament(BuildContext context, String id) =>
    Navigator.of(context).push(MaterialPageRoute(
        settings: RouteSettings(name: 'tournament:$id'),
        builder: (_) => TournamentScreen(tournamentId: id)));

/// One tournament: waiting room before it starts, then the Hall (bracket
/// or tables, watch every table, chat), then the podium.
class TournamentScreen extends StatefulWidget {
  final String tournamentId;
  const TournamentScreen({super.key, required this.tournamentId});

  @override
  State<TournamentScreen> createState() => _TournamentScreenState();
}

class _TournamentScreenState extends State<TournamentScreen> {
  late final TournamentLive live;
  Timer? _tick;
  int _tab = 0; // 0 bracket/tables · 1 watch · 2 chat
  bool _busy = false;
  final _chat = TextEditingController();

  String? get _me => context.read<AuthProvider>().user?.id;

  @override
  void initState() {
    super.initState();
    live = TournamentLive(widget.tournamentId, context.read<SocketService>().socket);
    live.addListener(_events);
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    live.removeListener(_events);
    live.dispose();
    _chat.dispose();
    super.dispose();
  }

  bool _matchSheetOpen = false;
  void _events() {
    final ym = live.yourMatch;
    if (ym != null && !_matchSheetOpen) {
      live.yourMatch = null;
      _showMatchReady(ym);
    }
    final fin = live.finished;
    if (fin != null) {
      live.finished = null;
      final trophy = fin['trophy'] as int? ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('You finished #${fin['place']}${trophy > 0 ? ' · +$trophy Trophy coins' : ''}')));
    }
  }

  Future<void> _showMatchReady(Map<String, dynamic> ym) async {
    _matchSheetOpen = true;
    final go = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      backgroundColor: const Color(0xFF16151B),
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('🎲', style: TextStyle(fontSize: 34)),
            const SizedBox(height: 6),
            Text(ym['final'] == true ? 'Your final is ready' : 'Your ${(ym['label'] as String? ?? 'table').toLowerCase()} is ready',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Round ${ym['round']} · join within 3 minutes or you’re out of this round',
                textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textDim)),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _purple, foregroundColor: Colors.white),
                onPressed: () => Navigator.of(sheet).pop(true),
                child: Text(ym['final'] == true ? 'Go to the final' : 'Go to table'),
              ),
            ),
          ]),
        ),
      ),
    );
    _matchSheetOpen = false;
    if (go == true && mounted) _openRoom(ym['roomId'] as String);
  }

  void _openRoom(String roomId) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => PartyScreen(roomId: roomId)));
  }

  Future<void> _post(String path, [Map<String, dynamic>? body, String? ok]) async {
    setState(() => _busy = true);
    try {
      await ApiClient.post('/tournaments/${widget.tournamentId}/$path', body: body ?? {});
      await live.refresh();
      if (ok != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok)));
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Something went wrong. Try again.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool get _isHost => live.data?['hostId'] == _me;

  void _share() {
    final d = live.data;
    showShareBottomSheet(context,
        text: 'Join ${d?['title'] ?? 'my tournament'} on Insync · ${tourGameLabel(live.gameType)} · free entry',
        url: '${ApiClient.baseUrl}/t/${widget.tournamentId}');
  }

  Future<void> _hostSheet() async {
    final matches = live.currentMatches.where((m) => m['status'] == 'playing').toList();
    final round = live.currentRound;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF16151B),
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('Host panel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            if (live.status == 'running') ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(12, 12, 12, 4),
                child: Text('📌 Pin a table for everyone',
                    style: TextStyle(color: AppColors.textDim, fontSize: 12)),
              ),
              for (final m in matches)
                ListTile(
                  dense: true,
                  title: Text(m['label'] as String),
                  trailing: live.data?['pinnedMatchId'] == m['id'] ? const Text('📌') : null,
                  onTap: () {
                    Navigator.of(sheet).pop();
                    _post('pin', {'matchId': live.data?['pinnedMatchId'] == m['id'] ? null : m['id']}, 'Pinned for everyone');
                  },
                ),
              if (round?['breakUntil'] != null && round?['extended'] != true)
                ListTile(
                  leading: const Text('⏸', style: TextStyle(fontSize: 18)),
                  title: const Text('Add 5 minutes to the break'),
                  subtitle: const Text('Once a round', style: TextStyle(color: AppColors.textDim)),
                  onTap: () {
                    Navigator.of(sheet).pop();
                    _post('extend', null, 'Break extended');
                  },
                ),
            ],
            ListTile(
              leading: const Text('🚫', style: TextStyle(fontSize: 18)),
              title: const Text('Remove someone'),
              subtitle: const Text('For bad behaviour', style: TextStyle(color: AppColors.textDim)),
              onTap: () {
                Navigator.of(sheet).pop();
                _removeSomeone();
              },
            ),
            if (live.status == 'open')
              ListTile(
                leading: const Text('✖️', style: TextStyle(fontSize: 18)),
                title: const Text('Cancel tournament', style: TextStyle(color: AppColors.danger)),
                subtitle: const Text('Your host fee is refunded', style: TextStyle(color: AppColors.textDim)),
                onTap: () {
                  Navigator.of(sheet).pop();
                  _post('cancel', null, 'Tournament cancelled');
                },
              ),
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('You can’t pick tables or decide winners — that’s random and automatic.',
                  style: TextStyle(color: AppColors.textFaint, fontSize: 11.5)),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _removeSomeone() async {
    final others = live.players.where((p) => p['id'] != _me).toList();
    final pick = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF16151B),
      builder: (sheet) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          for (final p in others)
            ListTile(
              leading: Avatar(src: p['avatarUrl'] as String?, name: p['name'] as String?, size: AvatarSize.sm),
              title: Text(p['name'] as String? ?? 'Player'),
              onTap: () => Navigator.of(sheet).pop(p['id'] as String),
            ),
        ]),
      ),
    );
    if (pick != null) _post('remove', {'userId': pick}, 'Removed');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: live,
      builder: (context, _) {
        final d = live.data;
        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            title: Text(d == null ? 'Tournament' : '${kTourGames[live.gameType]?.$1 ?? '🏆'} ${d['title']}',
                overflow: TextOverflow.ellipsis),
            actions: [
              if (d != null)
                IconButton(
                    tooltip: 'Share',
                    onPressed: _share,
                    icon: const InIcon(InIcons.share, color: AppColors.text)),
              if (d != null && _isHost && (live.status == 'open' || live.status == 'running'))
                IconButton(
                    tooltip: 'Host panel',
                    onPressed: _hostSheet,
                    icon: const InIcon(InIcons.more, color: AppColors.text)),
            ],
          ),
          body: d == null
              ? Center(
                  child: live.error == null
                      ? const CircularProgressIndicator()
                      : Text(live.error!, style: const TextStyle(color: AppColors.textDim)))
              : switch (live.status) {
                  'open' => _waiting(d),
                  'running' => _running(d),
                  _ => _finished(d),
                },
        );
      },
    );
  }

  // ---------------- before it starts ----------------
  Widget _waiting(Map<String, dynamic> d) {
    final startsAt = DateTime.tryParse(d['startsAt'] as String? ?? '')?.toLocal() ?? DateTime.now();
    final players = live.players;
    final joined = players.any((p) => p['id'] == _me);
    final full = players.length >= (d['size'] as int? ?? 0);
    final isPairs = live.isPairs;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Center(
        child: Column(children: [
          const Text('Starts in', style: TextStyle(color: AppColors.textDim)),
          Text(tourCountdown(startsAt), style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700)),
          Text(_when(startsAt), style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
        ]),
      ),
      const SizedBox(height: 14),
      _card(Row(children: [
        Expanded(
            child: Text(joined ? '✅ You’re in' : '🎟️ Free to enter',
                style: const TextStyle(fontWeight: FontWeight.w700))),
        if (joined)
          TextButton(onPressed: _busy ? null : () => _post('leave', null, 'You left'), child: const Text('Leave')),
      ])),
      const SizedBox(height: 10),
      Text('Joined · ${players.length} of ${d['size']}',
          style: const TextStyle(color: AppColors.textDim, fontSize: 12.5)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final p in players)
          SizedBox(
            width: 52,
            child: Column(children: [
              Avatar(src: p['avatarUrl'] as String?, name: p['name'] as String?, size: AvatarSize.md),
              const SizedBox(height: 2),
              Text((p['name'] as String? ?? '').split(' ').first,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
            ]),
          ),
      ]),
      const SizedBox(height: 14),
      _rule('🎲', 'Tables are picked at random when it starts, and again every round'),
      _rule('📏', isPairs
          ? '1 vs 1 knockout${live.gameType == 'tictactoe' ? ' · best of 3' : ' · 10 min chess clock each'}'
          : 'Tables of 4 · top players go through · ${d['turnSec'] ?? 20} s a turn'),
      _rule('⏱', 'Each round ends by ${d['limitMin']} minutes · no-shows after 3 minutes are out'),
      _rule('🏆', 'Prizes: 🥇 ${_prize(0)} · 🥈 ${_prize(1)} · 🥉 ${_prize(2)} · 4th ${_prize(3)} Trophy coins'),
      _rule('🔔', 'We’ll remind you 10 minutes before'),
      const SizedBox(height: 4),
      Text('Fewer than ${d['minPlayers'] ?? 8} at start time = cancelled',
          style: const TextStyle(color: AppColors.textFaint, fontSize: 11.5)),
      const SizedBox(height: 16),
      if (!joined)
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: _purple, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(46)),
          onPressed: _busy || full ? null : () => _post('join', null, 'You’re in!'),
          child: Text(full ? 'Full' : 'Join · free'),
        ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: _share,
        icon: const InIcon(InIcons.useradd, size: 18),
        label: const Text('Invite friends'),
        style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.text,
            side: const BorderSide(color: AppColors.border),
            minimumSize: const Size.fromHeight(44)),
      ),
    ]);
  }

  String _prize(int i) => '${((live.data?['prizes'] as List?) ?? const [300, 150, 50, 50])[i]}';

  String _when(DateTime t) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    return '${days[t.weekday - 1]} ${t.day}/${t.month} · $h:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'AM' : 'PM'}';
  }

  Widget _rule(String emoji, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: _card(Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12.5))),
        ])),
      );

  Widget _card(Widget child, {Color? border, Color? color}) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color ?? const Color(0xFF1A1A20),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border ?? const Color(0xFF2A2A33)),
        ),
        child: child,
      );

  // ---------------- while it runs ----------------
  Widget _running(Map<String, dynamic> d) {
    final round = live.currentRound;
    final breakUntil = DateTime.tryParse(round?['breakUntil'] as String? ?? '')?.toLocal();
    final inBreak = round?['status'] == 'done' && breakUntil != null;
    final endsAt = DateTime.tryParse(round?['endsAt'] as String? ?? '')?.toLocal();
    final mine = live.myMatch(_me);
    final tabs = [live.isPairs ? 'Bracket' : 'Tables', 'Watch', 'Chat'];
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: inBreak ? const Color(0xFF1F1E26) : const Color(0xFF501313),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: inBreak ? AppColors.border : const Color(0xFFA32D2D)),
            ),
            child: Text(
                inBreak
                    ? 'Break · next round in ${tourCountdown(breakUntil)}'
                    : '● Round ${round?['n']}${round?['final'] == true ? ' · Final' : ''}',
                style: TextStyle(fontSize: 11.5, color: inBreak ? AppColors.text : const Color(0xFFF7C1C1))),
          ),
          const SizedBox(width: 8),
          if (!inBreak && endsAt != null)
            Text('ends by ${tourCountdown(endsAt)}', style: const TextStyle(color: AppColors.textDim, fontSize: 11.5)),
          const Spacer(),
          if (d['hallRoomId'] != null)
            TextButton.icon(
              onPressed: () => _openRoom(d['hallRoomId'] as String),
              icon: const InIcon(InIcons.mic, size: 16, color: AppColors.text),
              label: const Text('Hall voice', style: TextStyle(color: AppColors.text, fontSize: 12)),
            ),
        ]),
      ),
      if (mine != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
          child: Material(
            color: const Color(0xFF1C1A2E),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12), side: const BorderSide(color: _purpleLine)),
            child: ListTile(
              dense: true,
              leading: const Text('🎮', style: TextStyle(fontSize: 18)),
              title: Text('You’re playing · ${mine['label']}'),
              trailing: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _purple, foregroundColor: Colors.white),
                onPressed: () => _openRoom(mine['roomId'] as String),
                child: const Text('Go'),
              ),
            ),
          ),
        ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(children: [
          for (var i = 0; i < tabs.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(tabs[i]),
                selected: _tab == i,
                onSelected: (_) => setState(() => _tab = i),
                selectedColor: const Color(0xFF26215C),
                backgroundColor: const Color(0xFF1F1E26),
                labelStyle: TextStyle(color: _tab == i ? const Color(0xFFCECBF6) : AppColors.text, fontSize: 12.5),
                side: BorderSide(color: _tab == i ? _purpleLine : AppColors.border),
                showCheckmark: false,
              ),
            ),
        ]),
      ),
      const SizedBox(height: 4),
      Expanded(
        child: switch (_tab) {
          1 => TournamentWatchView(live: live),
          2 => _chatView(),
          _ => live.isPairs ? _bracket() : _tables(),
        },
      ),
    ]);
  }

  Widget _bracket() {
    final rounds = live.rounds;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final r in rounds)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: SizedBox(
              width: 150,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r['final'] == true ? 'Final' : 'Round ${r['n']}',
                    style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
                const SizedBox(height: 6),
                for (final m in (r['matches'] as List).cast<Map>())
                  _matchBox(Map<String, dynamic>.from(m)),
              ]),
            ),
          ),
        const Padding(
          padding: EdgeInsets.only(top: 24),
          child: Text('🏆', style: TextStyle(fontSize: 30)),
        ),
      ]),
    );
  }

  Widget _matchBox(Map<String, dynamic> m) {
    final players = (m['players'] as List).cast<String>();
    final ranking = (m['ranking'] as List).cast<String>();
    final dropped = (m['dropped'] as List).cast<String>();
    final score = (m['score'] as Map?) ?? {};
    final live_ = m['status'] == 'playing';
    return GestureDetector(
      onTap: m['roomId'] == null ? null : () => setState(() => _tab = 1),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A20),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: live_ ? _purpleLine : AppColors.border),
        ),
        child: Column(children: [
          for (final uid in players)
            Row(children: [
              Expanded(
                child: Text(uid == _me ? 'You' : live.nameOf(uid),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: ranking.isNotEmpty && ranking.first == uid && !live_
                          ? _gold
                          : dropped.contains(uid)
                              ? AppColors.textFaint
                              : AppColors.text,
                    )),
              ),
              Text(m['bye'] == true ? 'free pass' : (dropped.contains(uid) ? '–' : '${score[uid] ?? 0}'),
                  style: const TextStyle(fontSize: 11.5, color: AppColors.textDim)),
            ]),
          if (live_)
            const Align(
                alignment: Alignment.centerRight,
                child: Text('● live · watch', style: TextStyle(color: Color(0xFFCECBF6), fontSize: 10.5))),
          if (m['note'] != null)
            Text(m['note'] as String, style: const TextStyle(color: AppColors.textFaint, fontSize: 10.5)),
        ]),
      ),
    );
  }

  Widget _tables() {
    final rounds = live.rounds.reversed.toList();
    return ListView(padding: const EdgeInsets.all(12), children: [
      for (final r in rounds) ...[
        Text(
            r['final'] == true
                ? 'Final table'
                : 'Round ${r['n']} · top ${r['advance']} of each table go${r['advance'] == 1 ? 'es' : ''} through',
            style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
        const SizedBox(height: 6),
        for (final m in (r['matches'] as List).cast<Map>()) _tableCard(Map<String, dynamic>.from(m), r),
        const SizedBox(height: 10),
      ],
    ]);
  }

  Widget _tableCard(Map<String, dynamic> m, Map r) {
    final players = (m['players'] as List).cast<String>();
    final ranking = (m['ranking'] as List).cast<String>();
    final dropped = (m['dropped'] as List).cast<String>();
    final done = m['status'] == 'done';
    final through = ranking.where((u) => !dropped.contains(u)).take(r['advance'] as int? ?? 1).toSet();
    return GestureDetector(
      onTap: done ? null : () => setState(() => _tab = 1),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A20),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: done ? _goldLine : _purpleLine),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(m['label'] as String, style: const TextStyle(fontWeight: FontWeight.w700))),
            Text(done ? 'Done' : '● live · watch',
                style: TextStyle(fontSize: 11.5, color: done ? _gold : const Color(0xFFCECBF6))),
          ]),
          const SizedBox(height: 4),
          Wrap(spacing: 10, children: [
            for (final uid in done ? ranking : players)
              Text(
                  '${through.contains(uid) && done ? '🥇 ' : ''}${uid == _me ? 'You' : live.nameOf(uid).split(' ').first}${dropped.contains(uid) ? ' (out)' : ''}',
                  style: TextStyle(
                      fontSize: 12.5,
                      color: through.contains(uid) && done
                          ? _gold
                          : dropped.contains(uid)
                              ? AppColors.textFaint
                              : AppColors.text)),
          ]),
          if (m['note'] != null)
            Text(m['note'] as String, style: const TextStyle(color: AppColors.textFaint, fontSize: 11)),
        ]),
      ),
    );
  }

  Widget _chatView() {
    final lines = live.chat;
    return Column(children: [
      Expanded(
        child: lines.isEmpty
            ? const Center(child: Text('Say hi to the Hall', style: TextStyle(color: AppColors.textDim)))
            : ListView.builder(
                reverse: true,
                padding: const EdgeInsets.all(12),
                itemCount: lines.length,
                itemBuilder: (_, i) {
                  final l = lines[lines.length - 1 - i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Avatar(src: l['avatarUrl'] as String?, name: l['name'] as String?, size: AvatarSize.sm),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text.rich(TextSpan(children: [
                          TextSpan(
                              text: '${(l['name'] as String? ?? '').split(' ').first}: ',
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                          TextSpan(text: l['text'] as String? ?? ''),
                        ])),
                      ),
                    ]),
                  );
                },
              ),
      ),
      SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 8, 8),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _chat,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendChat(),
                decoration: const InputDecoration(hintText: 'Say something…', isDense: true),
              ),
            ),
            IconButton(onPressed: _sendChat, icon: const InIcon(InIcons.send, color: AppColors.text)),
          ]),
        ),
      ),
    ]);
  }

  void _sendChat() {
    live.sendChat(_chat.text);
    _chat.clear();
  }

  // ---------------- after ----------------
  Widget _finished(Map<String, dynamic> d) {
    if (live.status == 'cancelled') {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('This tournament was cancelled.\nFewer than 8 players joined, or the host cancelled it.',
              textAlign: TextAlign.center, style: TextStyle(color: AppColors.textDim)),
        ),
      );
    }
    final results = ((d['results'] as List?) ?? []).whereType<Map>().toList();
    Map? at(int place) => results.where((r) => r['place'] == place).firstOrNull;
    final mine = results.where((r) => r['userId'] == _me).firstOrNull;
    Widget step(int place, double h, String medal) {
      final r = at(place);
      final uid = r?['userId'] as String?;
      return Column(mainAxisSize: MainAxisSize.min, children: [
        Avatar(src: live.avatarOf(uid), name: live.nameOf(uid), size: place == 1 ? AvatarSize.lg : AvatarSize.md),
        const SizedBox(height: 4),
        Container(
          width: 76,
          height: h,
          alignment: Alignment.topCenter,
          padding: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(
            color: place == 1 ? _goldBg : const Color(0xFF2A2A33),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
          ),
          child: Text('$medal\n${uid == null ? '—' : (uid == _me ? 'You' : live.nameOf(uid).split(' ').first)}',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: place == 1 ? _gold : AppColors.text)),
        ),
      ]);
    }

    return ListView(padding: const EdgeInsets.all(16), children: [
      const Center(child: Text('Final results', style: TextStyle(color: AppColors.textDim))),
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
        step(2, 70, '🥈'),
        const SizedBox(width: 8),
        step(1, 100, '🥇'),
        const SizedBox(width: 8),
        step(3, 52, '🥉'),
      ]),
      const SizedBox(height: 16),
      if (mine != null && (mine['trophy'] as int? ?? 0) > 0)
        _card(
          Column(children: [
            Text('+${mine['trophy']} 🏆', style: const TextStyle(color: _gold, fontSize: 22, fontWeight: FontWeight.w700)),
            const Text('Trophy coins added · only for VIP', style: TextStyle(color: _gold, fontSize: 12)),
          ]),
          border: _goldLine,
          color: const Color(0xFF1E1A10),
        ),
      if (mine?['place'] == 1) ...[
        const SizedBox(height: 8),
        _card(Text('🎖️  ${kTourGames[live.gameType]?.$2 ?? ''} Champion badge added to your profile')),
      ],
      const SizedBox(height: 8),
      for (final r in results)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
              '#${r['place']}  ${r['userId'] == _me ? 'You' : live.nameOf(r['userId'] as String?)}${(r['trophy'] as int? ?? 0) > 0 ? ' · +${r['trophy']} Trophy coins' : ''}',
              style: const TextStyle(color: AppColors.textDim, fontSize: 12.5)),
        ),
      const SizedBox(height: 16),
      if (mine != null && (mine['trophy'] as int? ?? 0) > 0)
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: _purple, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(46)),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VipStoreScreen())),
          child: const Text('Use for VIP'),
        ),
      const SizedBox(height: 8),
      OutlinedButton(
        onPressed: _share,
        style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.text,
            side: const BorderSide(color: AppColors.border),
            minimumSize: const Size.fromHeight(44)),
        child: const Text('Share result'),
      ),
    ]);
  }
}
