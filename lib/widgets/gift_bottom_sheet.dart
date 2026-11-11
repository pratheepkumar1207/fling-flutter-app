import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../core/auth_provider.dart';
import '../core/format.dart';
import '../models/gift.dart';
import '../screens/wallet/wallet_buy_screen.dart';
import '../theme/app_colors.dart';
import 'avatar.dart';
import 'gift_fx.dart';
import 'spinner.dart';

/// Someone a gift can go to, for the "To ▾" menu in a room.
class GiftRecipient {
  final String id;
  final String name;
  final String? avatarUrl;
  const GiftRecipient(this.id, this.name, {this.avatarUrl});
}

/// A short strip of gifts along the bottom, so what's on screen stays visible
/// while choosing. In a room everyone sees the gift through the room's own
/// event; elsewhere it plays here for the sender.
Future<void> showGiftBottomSheet(
  BuildContext context, {
  required String toUserId,
  String? roomId,
  VoidCallback? onSent,
  List<GiftRecipient> recipients = const [],
  // Room chat: nothing is sent until a person is picked (or was tagged in
  // the message box, which comes in as toUserId).
  bool requirePick = false,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.transparent,
    builder: (_) => _GiftSheet(
        toUserId: toUserId,
        roomId: roomId,
        onSent: onSent,
        recipients: recipients,
        requirePick: requirePick),
  );
}

class _GiftSheet extends StatefulWidget {
  final String toUserId;
  final String? roomId;
  final VoidCallback? onSent;
  final List<GiftRecipient> recipients;
  final bool requirePick;
  const _GiftSheet(
      {required this.toUserId,
      this.roomId,
      this.onSent,
      this.recipients = const [],
      this.requirePick = false});

  @override
  State<_GiftSheet> createState() => _GiftSheetState();
}

class _GiftSheetState extends State<_GiftSheet> {
  bool _sending = false;
  List<Gift>? _gifts;
  Gift? _selected;
  String _tab = 'popular';
  int _qty = 1;
  late String _to = widget.toUserId;
  // Same gift sent again within a few seconds builds a combo.
  String? _comboType;
  int _combo = 0;
  DateTime _comboAt = DateTime(2000);

  static const _tabs = [
    ('popular', 'Popular'),
    ('love', 'Love'),
    ('lucky', 'Lucky'),
    ('fan', 'Fan club'),
  ];

  @override
  void initState() {
    super.initState();
    _loadGifts();
  }

  Future<void> _loadGifts() async {
    try {
      final data = await ApiClient.get('/wallet/gifts');
      if (!mounted) return;
      setState(() => _gifts = (data as List)
          .map((e) => Gift.fromJson(e as Map<String, dynamic>))
          .toList());
    } catch (_) {
      if (mounted) setState(() => _gifts = []);
    }
  }

  Future<void> _send() async {
    final gift = _selected;
    if (gift == null || _sending || _to.isEmpty) return;
    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    final auth = context.read<AuthProvider>();
    final me = auth.user?.name ?? 'You';
    try {
      // No `coins` in the body: the server looks the price up by type.
      final res = await ApiClient.post('/wallet/gift', body: {
        'roomId': widget.roomId,
        'toUserId': _to,
        'giftType': gift.type,
        'quantity': _qty,
      }) as Map;
      widget.onSent?.call();
      auth.refreshUser();
      if (widget.roomId == null && mounted) {
        GiftFx.play(
            context,
            GiftEvent(
              emoji: gift.emoji,
              name: gift.name,
              type: gift.type,
              coins: gift.coins,
              diamonds: (res['diamonds'] as num?) ?? 0,
              quantity: _qty,
              fromName: me,
              toName: res['toName'] as String?,
              toUserId: _to,
            ));
      }
      final now = DateTime.now();
      final again =
          _comboType == gift.type && now.difference(_comboAt).inSeconds < 6;
      if (mounted) {
        setState(() {
          _combo = again ? _combo + 1 : 1;
          _comboType = gift.type;
          _comboAt = now;
        });
      }
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Couldn’t send that. Try again.')));
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (mounted) setState(() => _sending = false);
  }

  Widget _tile(Gift gift) {
    final selected = _selected?.id == gift.id;
    return Semantics(
      button: true,
      selected: selected,
      label: '${gift.name}, ${gift.coins} coins',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _selected = gift),
        child: SizedBox(
          width: 68,
          child: AnimatedScale(
            scale: selected ? 1.14 : 1,
            duration: const Duration(milliseconds: 120),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(gift.emoji,
                  style: const TextStyle(fontSize: 34, height: 1.15)),
              Text(gift.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: selected ? Colors.white : const Color(0xFFC9C4D6),
                      fontSize: 11,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w400)),
              Text(formatNumber(gift.coins),
                  style: const TextStyle(color: AppColors.gold, fontSize: 11)),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final coins = context.watch<AuthProvider>().user?.coinBalance ?? 0;
    final gifts = _gifts;
    final hasTab = gifts?.any((g) => g.category == _tab) ?? false;
    final shown = gifts == null
        ? const <Gift>[]
        : hasTab
            ? gifts.where((g) => g.category == _tab).toList()
            : gifts;
    final toName = widget.recipients
        .where((r) => r.id == _to)
        .map((r) => r.name)
        .firstOrNull;
    final pick = widget.requirePick;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.sheet,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (pick) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(14, 12, 14, 6),
                  child: Text('Who’s this gift for?',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                ),
                SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      for (final r in widget.recipients)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Semantics(
                            button: true,
                            selected: _to == r.id,
                            label: 'Gift to ${r.name}',
                            child: GestureDetector(
                              onTap: () => setState(() => _to = r.id),
                              child: Container(
                                padding: const EdgeInsets.fromLTRB(3, 3, 10, 3),
                                decoration: BoxDecoration(
                                  color: _to == r.id
                                      ? AppColors.primary
                                          .withValues(alpha: 0.35)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(17),
                                  border: Border.all(
                                      color: _to == r.id
                                          ? AppColors.primary
                                          : Colors.white24),
                                ),
                                child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox.square(
                                        dimension: 24,
                                        child: FittedBox(
                                            child: Avatar(
                                                src: r.avatarUrl,
                                                name: r.name,
                                                size: AvatarSize.sm)),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(r.name,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12.5)),
                                    ]),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  children: [
                    for (final (id, label) in _tabs)
                      if (gifts?.any((g) => g.category == id) ?? false)
                        TextButton(
                          onPressed: () => setState(() => _tab = id),
                          child: Text(label,
                              style: TextStyle(
                                  color: _tab == id
                                      ? Colors.white
                                      : const Color(0xFFA9A3B8),
                                  fontSize: 13,
                                  fontWeight: _tab == id
                                      ? FontWeight.w700
                                      : FontWeight.w400)),
                        ),
                  ],
                ),
              ),
              SizedBox(
                height: 86,
                child: gifts == null
                    ? const Center(child: Spinner(size: 20))
                    : gifts.isEmpty
                        ? const Center(
                            child: Text('No gifts available right now.',
                                style: TextStyle(color: AppColors.textFaint)))
                        : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            itemCount: shown.length,
                            itemBuilder: (_, i) => _tile(shown[i]),
                          ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                child: Row(children: [
                  InkWell(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const WalletBuyScreen())),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text('🪙 ${formatNumber(coins)} ＋',
                          style: const TextStyle(
                              color: AppColors.gold, fontSize: 12.5)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (pick)
                    const Spacer()
                  else if (widget.recipients.length > 1)
                    Expanded(
                      child: PopupMenuButton<String>(
                        tooltip: 'Who gets the gift',
                        onSelected: (id) => setState(() => _to = id),
                        itemBuilder: (_) => [
                          for (final r in widget.recipients)
                            PopupMenuItem(value: r.id, child: Text(r.name)),
                        ],
                        child: Text('To ${toName ?? 'Host'} ▾',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12.5)),
                      ),
                    )
                  else
                    const Spacer(),
                  PopupMenuButton<int>(
                    tooltip: 'How many',
                    onSelected: (q) => setState(() => _qty = q),
                    itemBuilder: (_) => [
                      for (final q in const [1, 10, 99])
                        PopupMenuItem(value: q, child: Text('×$q')),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text('×$_qty ▾',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12.5)),
                    ),
                  ),
                  FilledButton(
                    onPressed: _selected == null || _sending || _to.isEmpty
                        ? null
                        : _send,
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.lilac,
                        foregroundColor: const Color(0xFF241338),
                        minimumSize: const Size(0, 38),
                        padding: const EdgeInsets.symmetric(horizontal: 14)),
                    child: Text(_combo >= 2
                        ? 'Combo ×$_combo'
                        : pick && _to.isEmpty
                            ? 'Pick who it’s for'
                            : _selected == null
                                ? 'Send'
                                : pick
                                    ? 'Send ${_selected!.emoji} to ${(toName ?? '').split(' ').first}'
                                    : 'Send ${formatNumber(_selected!.coins * _qty)}'),
                  ),
                ]),
              ),
            ]),
      ),
    );
  }
}
