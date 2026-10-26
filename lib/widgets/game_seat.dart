import '../theme/insync_icons.dart';
import 'package:flutter/material.dart';
import '../core/profile_nav.dart';
import '../theme/app_colors.dart';
import 'avatar.dart';

/// Who may sit down at the game and how — provided by party_screen.dart
/// around whichever board is showing, so each board only decides *where*
/// its seats and its join button go, not the request/invite rules (those
/// live server-side in syncHandler.js's game:request / game:invite):
/// the host sits down straight away, a guest asks to play (or accepts the
/// host's invite).
class GameSeatScope extends InheritedWidget {
  final bool isHost;
  final bool requested;
  final bool invited;
  final VoidCallback onSit;
  final VoidCallback onRequest;
  final VoidCallback onCancelRequest;
  // Host only — opens the "who should play?" picker.
  final VoidCallback? onInvite;
  final String? Function(String? userId) avatarFor;

  const GameSeatScope({
    super.key,
    required this.isHost,
    required this.requested,
    required this.invited,
    required this.onSit,
    required this.onRequest,
    required this.onCancelRequest,
    required this.onInvite,
    required this.avatarFor,
    required super.child,
  });

  static GameSeatScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GameSeatScope>();

  @override
  bool updateShouldNotify(GameSeatScope old) =>
      isHost != old.isHost ||
      requested != old.requested ||
      invited != old.invited;
}

const kTurnRing = AppColors.accent;

/// One player's seat: avatar (lime ring on their turn), name, and an
/// optional detail line (symbol, card count, colour…).
class GameSeat extends StatelessWidget {
  final String? userId;
  final String? name;
  final bool isTurn;
  final bool isMe;
  final Color? color;
  final Widget? detail;
  final double size;
  final Axis direction;

  const GameSeat({
    super.key,
    required this.userId,
    required this.name,
    this.isTurn = false,
    this.isMe = false,
    this.color,
    this.detail,
    this.size = 34,
    this.direction = Axis.vertical,
  });

  @override
  Widget build(BuildContext context) {
    final scope = GameSeatScope.of(context);
    final ringColor = isTurn ? kTurnRing : (color ?? Colors.transparent);
    final avatar = GestureDetector(
      onTap: () => openProfile(context, userId),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: ringColor, width: 2),
        ),
        child: SizedBox(
          width: size,
          height: size,
          child: FittedBox(
            child: Avatar(src: scope?.avatarFor(userId), name: name),
          ),
        ),
      ),
    );
    final label = Text(
      isMe ? 'You' : (name ?? 'Player'),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: isTurn ? kTurnRing : AppColors.text,
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
      ),
    );
    final text = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: direction == Axis.vertical
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        label,
        if (detail != null)
          DefaultTextStyle.merge(
            style: const TextStyle(color: AppColors.textFaint, fontSize: 11),
            child: detail!,
          ),
      ],
    );
    return Semantics(
      label:
          '${isMe ? 'You' : name ?? 'Player'}${isTurn ? ', their turn' : ''}',
      child: direction == Axis.vertical
          ? SizedBox(
              width: size + 36,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [avatar, const SizedBox(height: 3), text],
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                avatar,
                const SizedBox(width: 6),
                Flexible(child: text),
              ],
            ),
    );
  }
}

/// An empty seat. The host taps it to invite someone; a guest to ask.
class GameOpenSeat extends StatelessWidget {
  final double size;
  final Axis direction;
  const GameOpenSeat(
      {super.key, this.size = 34, this.direction = Axis.vertical});

  @override
  Widget build(BuildContext context) {
    final scope = GameSeatScope.of(context);
    final onTap = scope == null
        ? null
        : scope.isHost
            ? scope.onInvite
            : (scope.requested || scope.invited ? null : scope.onRequest);
    final circle = Container(
      width: size + 4,
      height: size + 4,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.textFaint, width: 1.2),
      ),
      alignment: Alignment.center,
      child: const InIcon(InIcons.plus, color: AppColors.textFaint, size: 18),
    );
    const label = Text('Open',
        style: TextStyle(color: AppColors.textFaint, fontSize: 11.5));
    return Semantics(
      button: onTap != null,
      label: 'Open seat',
      child: GestureDetector(
        onTap: onTap,
        child: direction == Axis.vertical
            ? SizedBox(
                width: size + 36,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  circle,
                  const SizedBox(height: 3),
                  label,
                ]),
              )
            : Row(mainAxisSize: MainAxisSize.min, children: [
                circle,
                const SizedBox(width: 6),
                label,
              ]),
      ),
    );
  }
}

/// The one "get into the game" control every board shows when I'm not
/// seated: Play (host), Join game (invited), Requested (asked, waiting),
/// or Ask to play. Plus Invite next to it for the host. Nothing once
/// seated, or when the game is full and I'm not the host.
class GameJoinButton extends StatelessWidget {
  final bool seated;
  final bool full;
  // Used when there's no GameSeatScope above (e.g. a board shown on its own).
  final VoidCallback? fallbackJoin;

  const GameJoinButton(
      {super.key, required this.seated, required this.full, this.fallbackJoin});

  @override
  Widget build(BuildContext context) {
    final scope = GameSeatScope.of(context);
    if (scope == null) {
      if (seated || full || fallbackJoin == null) {
        return const SizedBox.shrink();
      }
      return _primary('Join game', fallbackJoin);
    }
    final buttons = <Widget>[];
    if (!seated && !full) {
      if (scope.isHost) {
        buttons.add(_primary('Play', scope.onSit));
      } else if (scope.invited) {
        buttons.add(_primary('Join game', scope.onSit));
      } else if (scope.requested) {
        buttons.add(_secondary('Requested · Cancel', scope.onCancelRequest,
            icon: InIcons.calendar));
      } else {
        buttons.add(_primary('Ask to play', scope.onRequest));
      }
    }
    if (scope.isHost && !full && scope.onInvite != null) {
      buttons.add(_secondary('Invite', scope.onInvite, icon: InIcons.useradd));
    }
    if (buttons.isEmpty) return const SizedBox.shrink();
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 6,
      children: buttons,
    );
  }

  Widget _primary(String label, VoidCallback? onTap) => FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.ink,
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        child: Text(label),
      );

  Widget _secondary(String label, VoidCallback? onTap, {InIconData? icon}) =>
      OutlinedButton.icon(
        onPressed: onTap,
        icon: icon == null ? const SizedBox.shrink() : InIcon(icon, size: 16),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.text,
          side: const BorderSide(color: AppColors.border),
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          textStyle:
              const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
        ),
      );
}

/// The one-line "whose turn / who won" text above every board.
class GameStatusLine extends StatelessWidget {
  final String text;
  final bool highlight;
  const GameStatusLine(this.text, {super.key, this.highlight = true});

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: highlight ? AppColors.accent : AppColors.textDim,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
