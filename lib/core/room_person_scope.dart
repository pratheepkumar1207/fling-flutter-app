import 'package:flutter/material.dart';
import 'profile_nav.dart';

/// Inside a room, tapping a person opens the profile card over the room and
/// long-pressing opens the host's options. Anywhere else there's no scope,
/// and a tap goes to the full profile as usual.
class RoomPersonScope extends InheritedWidget {
  final void Function(String userId) onTap;
  final void Function(String userId, Rect anchor) onLongPress;

  const RoomPersonScope({
    super.key,
    required this.onTap,
    required this.onLongPress,
    required super.child,
  });

  static RoomPersonScope? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<RoomPersonScope>();

  @override
  bool updateShouldNotify(RoomPersonScope oldWidget) => false;
}

void openRoomPerson(BuildContext context, String? userId) {
  if (userId == null || userId.isEmpty) return;
  final scope = RoomPersonScope.maybeOf(context);
  if (scope == null) {
    openProfile(context, userId);
  } else {
    scope.onTap(userId);
  }
}

/// Anchored to [context]'s own box, so the popup can sit beside that seat.
void longPressRoomPerson(BuildContext context, String? userId) {
  if (userId == null || userId.isEmpty) return;
  final box = context.findRenderObject();
  if (box is! RenderBox) return;
  final anchor = box.localToGlobal(Offset.zero) & box.size;
  RoomPersonScope.maybeOf(context)?.onLongPress(userId, anchor);
}
