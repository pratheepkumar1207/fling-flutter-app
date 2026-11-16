import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/auth_provider.dart';
import '../screens/settings/creator_account_screen.dart';
import '../theme/app_colors.dart';
import '../theme/insync_icons.dart';

/// Going live is for creator accounts, once approved. Shows why not (with a
/// way to switch) and returns false when this account can't go live yet.
Future<bool> canGoLive(BuildContext context) async {
  final user = context.read<AuthProvider>().user;
  if (user?.isCreator == true && user?.livestreamStatus == 'approved') {
    return true;
  }
  final creator = user?.isCreator == true;
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.black,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const InIcon(InIcons.live, size: 34, color: Color(0xFFFF375F)),
              const SizedBox(height: 12),
              Text(
                  creator
                      ? 'Your live is under review'
                      : 'Switch to a creator account to go live',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                  creator
                      ? 'We’ll tell you as soon as you’re approved to go live.'
                      : 'Creators can go live, offer Silver, Gold and Platinum subscriptions and post for subscribers. It’s free.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textDim, height: 1.4)),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () {
                  Navigator.of(sheet).pop();
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const CreatorAccountScreen()));
                },
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48)),
                child: Text(creator ? 'See status' : 'Switch to creator'),
              ),
            ]),
      ),
    ),
  );
  return false;
}
