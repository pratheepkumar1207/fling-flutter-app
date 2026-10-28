import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/insync_icons.dart';
import '../../widgets/avatar.dart';

/// What the person chose on the incoming call screen.
enum CallAnswer { accept, decline, message, remind }

/// Full-screen incoming call. Pops a [CallAnswer] (and `null` when the
/// caller hangs up first — see AppShell).
Future<CallAnswer?> showIncomingCall(BuildContext context,
    {required String name, String? avatarUrl, required bool video}) {
  return showGeneralDialog<CallAnswer>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black,
    pageBuilder: (dialog, _, __) => IncomingCallView(
      name: name,
      avatarUrl: avatarUrl,
      video: video,
      onAccept: () => Navigator.of(dialog).pop(CallAnswer.accept),
      onDecline: () => Navigator.of(dialog).pop(CallAnswer.decline),
      onMessage: () => Navigator.of(dialog).pop(CallAnswer.message),
      onRemind: () => Navigator.of(dialog).pop(CallAnswer.remind),
    ),
  );
}

class IncomingCallView extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final bool video;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  /// Decline and open the chat / decline and get reminded later.
  final VoidCallback? onMessage;
  final VoidCallback? onRemind;
  const IncomingCallView(
      {super.key,
      required this.name,
      this.avatarUrl,
      required this.video,
      required this.onAccept,
      required this.onDecline,
      this.onMessage,
      this.onRemind});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
                center: Alignment(0, -0.4),
                radius: 1,
                colors: [Color(0xFF3A1A5A), AppColors.bg]),
          ),
          child: SafeArea(
            child: Column(children: [
              const Spacer(),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                InIcon(video ? InIcons.video : InIcons.phone,
                    size: 16, color: AppColors.textDim),
                const SizedBox(width: 6),
                Text(video ? 'Insync video call' : 'Insync audio call',
                    style: const TextStyle(
                        color: AppColors.textDim, fontSize: 13)),
              ]),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppGradients.brandDiagonal,
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.purple.withValues(alpha: 0.14),
                        spreadRadius: 16),
                    BoxShadow(
                        color: AppColors.purple.withValues(alpha: 0.07),
                        spreadRadius: 34),
                  ],
                ),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                      color: AppColors.bg, shape: BoxShape.circle),
                  child: SizedBox(
                    width: 126,
                    height: 126,
                    child: FittedBox(
                        child: Avatar(
                            src: avatarUrl, name: name, size: AvatarSize.lg)),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 28, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 4),
              const Text('is calling you…',
                  style: TextStyle(color: AppColors.textDim, fontSize: 14)),
              const Spacer(flex: 2),
              if (onMessage != null || onRemind != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(40, 0, 40, 28),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        if (onMessage != null)
                          _small('Message', InIcons.chat, onMessage!),
                        if (onRemind != null)
                          _small('Remind me', InIcons.bell, onRemind!),
                      ]),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(40, 0, 40, 40),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _button('Decline', InIcons.phoneoff, AppColors.danger,
                          onDecline),
                      _button('Accept', video ? InIcons.video : InIcons.phone,
                          AppColors.success, onAccept),
                    ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _small(String label, InIconData icon, VoidCallback onTap) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 34,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
                color: AppColors.surface2, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: InIcon(icon, size: 22, color: AppColors.text),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: const TextStyle(fontSize: 12, color: AppColors.textDim)),
        ]),
      ),
    );
  }

  Widget _button(
      String label, InIconData icon, Color color, VoidCallback onTap) {
    return Semantics(
      button: true,
      label: label,
      child: InkResponse(
        onTap: onTap,
        radius: 44,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: InIcon(icon, size: 30, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 13)),
        ]),
      ),
    );
  }
}
