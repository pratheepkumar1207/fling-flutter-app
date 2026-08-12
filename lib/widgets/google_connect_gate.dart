import 'package:flutter/material.dart';
import '../core/google_content_service.dart';
import '../theme/app_colors.dart';
import 'spinner.dart';

/// Wraps a Google-account-only screen section (YouTube playlists/liked,
/// Drive browse): checks connection status first, and if not connected
/// shows a "Connect Google account" prompt instead of hitting an endpoint
/// that would 403. Shared by youtube_browse_screen.dart and
/// drive_browse_screen.dart.
class GoogleConnectGate extends StatefulWidget {
  final Widget child;
  const GoogleConnectGate({super.key, required this.child});

  @override
  State<GoogleConnectGate> createState() => _GoogleConnectGateState();
}

class _GoogleConnectGateState extends State<GoogleConnectGate> {
  bool? _connected;
  bool _connecting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    try {
      final status = await GoogleContentService.instance.status();
      if (mounted) setState(() => _connected = status['connected'] == true);
    } catch (_) {
      if (mounted) setState(() => _connected = false);
    }
  }

  Future<void> _connect() async {
    setState(() {
      _connecting = true;
      _error = null;
    });
    try {
      await GoogleContentService.instance.connect();
      if (mounted) setState(() => _connected = true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_connected == null) return const Center(child: Spinner());
    if (_connected == false) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🔗', style: TextStyle(fontSize: 36)),
              const SizedBox(height: 12),
              const Text('Connect your Google account to browse it here.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textDim, fontSize: 13)),
              const SizedBox(height: 16),
              if (!GoogleContentService.isConfigured)
                const Text('Google sign-in isn\'t set up on this build yet.', style: TextStyle(color: AppColors.textFaint, fontSize: 11))
              else
                ElevatedButton(onPressed: _connecting ? null : _connect, child: Text(_connecting ? 'Connecting…' : 'Connect Google account')),
              if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 11), textAlign: TextAlign.center)),
            ],
          ),
        ),
      );
    }
    return widget.child;
  }
}
