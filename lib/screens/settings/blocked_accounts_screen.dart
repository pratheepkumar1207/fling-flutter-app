import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_image.dart';
import '../../widgets/spinner.dart';

// Deterministic per-user gradient for the initials fallback, matching
// BlockedAccountsDark.dc.html's colorful avatars — scoped to this screen
// rather than changed globally on widgets/avatar.dart's plain-gray
// fallback, which is used all over the app and not part of this mockup.
const _kAvatarGradients = [
  [Color(0xFFC9825A), Color(0xFF5C2E17)],
  [Color(0xFF5A82B8), Color(0xFF1E3A5C)],
  [Color(0xFFB8A25A), Color(0xFF4C4017)],
  [Color(0xFFA5709A), Color(0xFF4C2447)],
  [Color(0xFF6BAF8A), Color(0xFF1E4C34)],
];

/// GET /social/blocklist + POST /social/unblock/:userId — the app could
/// block someone (from CreatorProfileScreen) but had no way to see or undo
/// it afterward. This is the missing other half of that flow. Matches
/// BlockedAccountsDark.dc.html: custom rows with a colorful initials
/// avatar, name/username, a pill "Unblock" button, and a footer note.
class BlockedAccountsScreen extends StatefulWidget {
  const BlockedAccountsScreen({super.key});

  @override
  State<BlockedAccountsScreen> createState() => _BlockedAccountsScreenState();
}

class _BlockedAccountsScreenState extends State<BlockedAccountsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _blocked = [];
  final Set<String> _unblocking = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiClient.get('/social/blocklist');
      if (!mounted) return;
      setState(() {
        _blocked = (data as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _unblock(String userId) async {
    setState(() => _unblocking.add(userId));
    try {
      await ApiClient.post('/social/unblock/$userId');
      if (!mounted) return;
      setState(() => _blocked.removeWhere((u) => u['id'] == userId));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Failed to unblock')));
      }
    } finally {
      if (mounted) setState(() => _unblocking.remove(userId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Blocked accounts')),
      body: _loading
          ? const Center(child: Spinner())
          : _blocked.isEmpty
              ? const Center(
                  child: Text("You haven't blocked anyone.",
                      style: TextStyle(color: AppColors.textFaint)))
              : ListView(
                  padding: const EdgeInsets.only(top: 8),
                  children: [
                    for (var i = 0; i < _blocked.length; i++)
                      _row(_blocked[i], i),
                    const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                      child: Text(
                        "Blocked accounts can't view your profile, message you, or join rooms you're in.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: AppColors.textFaint,
                            fontSize: 12,
                            height: 1.6),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _row(Map<String, dynamic> u, int index) {
    final id = u['id'] as String;
    final name = u['name'] as String? ?? 'Unknown';
    final avatarUrl = u['avatarUrl'] as String?;
    final unblocking = _unblocking.contains(id);
    final gradient = _kAvatarGradients[index % _kAvatarGradients.length];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradient)),
            alignment: Alignment.center,
            child: avatarUrl != null
                ? AppImage(source: avatarUrl, fit: BoxFit.cover)
                : Text(initials(name),
                    style: GoogleFonts.bricolageGrotesque(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5)),
                if (u['username'] != null)
                  Text('@${u['username']}',
                      style: const TextStyle(
                          color: AppColors.textFaint, fontSize: 11.5)),
              ],
            ),
          ),
          GestureDetector(
            onTap: unblocking ? null : () => _unblock(id),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.border, width: 1.5)),
              child: Text(unblocking ? 'Unblocking…' : 'Unblock',
                  style: const TextStyle(
                      color: AppColors.textDim,
                      fontWeight: FontWeight.w700,
                      fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}
