import 'package:flutter/material.dart';

/// A bottom sheet with scrolling content: its scroll view takes the drag, so
/// the sheet's own swipe-down never fires. Pulling down from the top closes
/// it instead.
class SwipeDownToClose extends StatefulWidget {
  final Widget child;
  const SwipeDownToClose({super.key, required this.child});

  @override
  State<SwipeDownToClose> createState() => _SwipeDownToCloseState();
}

class _SwipeDownToCloseState extends State<SwipeDownToClose> {
  static const _distance = 48.0;
  double _pulled = 0;
  bool _closing = false;

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.axis != Axis.vertical) return false;
    if (n is OverscrollNotification && n.dragDetails != null) {
      if (n.overscroll < 0) _pulled -= n.overscroll;
    } else if (n is ScrollUpdateNotification && n.dragDetails != null) {
      // Platforms that bounce report the pull as a negative position.
      _pulled = n.metrics.pixels < 0 ? -n.metrics.pixels : 0;
    } else if (n is ScrollEndNotification) {
      _pulled = 0;
    }
    if (_pulled > _distance && !_closing) {
      _closing = true;
      Navigator.of(context).maybePop();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: widget.child,
      );
}
