import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/insync_clay.dart';

/// Who sees the room you're in (the "IN ROOM" card on your profile) and
/// what you liked. Every change saves straight away (PATCH /auth/me) and
/// rolls back if the save fails. The two older switches — online status
/// and location — are repeated here so all privacy lives in one place;
/// they still work from Edit profile and Settings too.
class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  late final _user = context.read<AuthProvider>().user;
  late String _roomVisibility = _user?.roomActivityVisibility ?? 'everyone';
  late bool _showNowPlaying = _user?.showNowPlaying ?? true;
  late bool _allowJoin = _user?.allowJoinFromProfile ?? true;
  late String _likesVisibility = _user?.likesVisibility ?? 'everyone';
  late bool _hideLikeCounts = _user?.hideLikeCounts ?? false;
  late bool _hideLikedSongs = _user?.hideLikedSongs ?? false;
  late bool _hideOnline = _user?.hideOnlineStatus ?? false;
  bool _saving = false;

  Future<void> _save(Map<String, dynamic> body, VoidCallback apply,
      VoidCallback revert) async {
    setState(() {
      apply();
      _saving = true;
    });
    try {
      await ApiClient.patch('/auth/me', body: body);
      if (mounted) await context.read<AuthProvider>().refreshUser();
    } catch (e) {
      if (!mounted) return;
      setState(revert);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e is ApiException
              ? e.message
              : "Couldn't save — check your connection")));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _header(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
        child: Text(text,
            style: const TextStyle(
                color: AppColors.textFaint,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      );

  Widget _switch(
      String label, String? help, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      value: value,
      onChanged: _saving ? null : onChanged,
      activeTrackColor: AppColors.primary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      title: Text(label,
          style: const TextStyle(color: AppColors.text, fontSize: 13.5)),
      subtitle: help == null
          ? null
          : Text(help,
              style: const TextStyle(color: AppColors.textFaint, fontSize: 12)),
    );
  }

  Widget _choice(String label, String value, List<(String, String)> options,
      ValueChanged<String> onChanged) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: AppColors.text, fontSize: 13.5)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: [
              for (final (v, l) in options)
                ButtonSegment(value: v, label: Text(l)),
            ],
            selected: {value},
            showSelectedIcon: false,
            onSelectionChanged: _saving ? null : (s) => onChanged(s.first),
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: AppColors.accent.withValues(alpha: 0.2),
              selectedForegroundColor: AppColors.accent,
              foregroundColor: AppColors.textDim,
              side: const BorderSide(color: AppColors.border),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const InsyncPageTitle('Privacy')),
      body: ListView(
        children: [
          _header('Room activity'),
          _choice(
            'Show the room I\'m in',
            _roomVisibility,
            const [
              ('everyone', 'Public'),
              ('friends', 'Friends only'),
              ('nobody', 'Private')
            ],
            (v) {
              final old = _roomVisibility;
              _save({'roomActivityVisibility': v}, () => _roomVisibility = v,
                  () => _roomVisibility = old);
            },
          ),
          // VIPs see everyone's room unless the person is a VIP too — say
          // which side of that this user is on.
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
            child: Text(
                _user?.isVip == true
                    ? 'As a VIP, this applies to everyone — other VIPs included.'
                    : "VIP members can still see the room you're in.",
                style:
                    const TextStyle(color: AppColors.textFaint, fontSize: 12)),
          ),
          _switch(
              'Show what I\'m watching or playing',
              'Off: people see you\'re in a room, but not what\'s on',
              _showNowPlaying,
              (v) => _save({'showNowPlaying': v}, () => _showNowPlaying = v,
                  () => _showNowPlaying = !v)),
          _switch(
              'Let people join from my profile',
              null,
              _allowJoin,
              (v) => _save({'allowJoinFromProfile': v}, () => _allowJoin = v,
                  () => _allowJoin = !v)),
          _header('Likes and activity'),
          _choice(
            'Who can see posts I liked',
            _likesVisibility,
            const [
              ('everyone', 'Everyone'),
              ('friends', 'Friends'),
              ('me', 'Only me')
            ],
            (v) {
              final old = _likesVisibility;
              _save({'likesVisibility': v}, () => _likesVisibility = v,
                  () => _likesVisibility = old);
            },
          ),
          _switch(
              'Hide like counts on my posts',
              'Only you will see how many people liked them',
              _hideLikeCounts,
              (v) => _save({'hideLikeCounts': v}, () => _hideLikeCounts = v,
                  () => _hideLikeCounts = !v)),
          _switch(
              'Hide liked songs on my profile',
              null,
              _hideLikedSongs,
              (v) => _save({'hideLikedSongs': v}, () => _hideLikedSongs = v,
                  () => _hideLikedSongs = !v)),
          _header('Online'),
          _switch(
              'Hide my online status',
              null,
              _hideOnline,
              (v) => _save({'hideOnlineStatus': v}, () => _hideOnline = v,
                  () => _hideOnline = !v)),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
