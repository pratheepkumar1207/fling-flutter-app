import 'package:flutter/material.dart';

import 'insync_brand.dart';

// Loading placeholders in the shape of what's coming (the feed's style):
// grey blocks with the brand shimmer running over them. Each screen picks
// the one that matches its layout.

const _kBlock = Color(0xFF241A44);

Widget _box({double? width, double height = 10, double radius = 6}) =>
    Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
          color: _kBlock, borderRadius: BorderRadius.circular(radius)),
    );

Widget _circle(double size) => Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(color: _kBlock, shape: BoxShape.circle),
    );

/// Posts: round photo and two lines, then a big picture.
class SkeletonPosts extends StatelessWidget {
  final int count;
  const SkeletonPosts({super.key, this.count = 2});

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Loading posts',
        child: InsyncShimmer(
          child: Column(children: [
            for (var i = 0; i < count; i++)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        _circle(34),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _box(width: 140),
                                const SizedBox(height: 6),
                                _box(width: 80, height: 8),
                              ]),
                        ),
                      ]),
                      const SizedBox(height: 12),
                      AspectRatio(
                          aspectRatio: 1,
                          child: _box(height: double.infinity, radius: 14)),
                      const SizedBox(height: 10),
                      _box(width: 200),
                    ]),
              ),
          ]),
        ),
      );
}

/// List rows: round photo and two lines (chats, notifications, people).
class SkeletonRows extends StatelessWidget {
  final int count;
  final double avatar;
  const SkeletonRows({super.key, this.count = 8, this.avatar = 44});

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Loading',
        child: InsyncShimmer(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            for (var i = 0; i < count; i++)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                child: Row(children: [
                  _circle(avatar),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FractionallySizedBox(
                              widthFactor: 0.5 + (i % 3) * 0.1,
                              child: _box()),
                          const SizedBox(height: 7),
                          FractionallySizedBox(
                              widthFactor: 0.75 - (i % 2) * 0.2,
                              child: _box(height: 8)),
                        ]),
                  ),
                ]),
              ),
          ]),
        ),
      );
}

/// Room cards (Popcorn): picture on the left, lines on the right.
class SkeletonRoomCards extends StatelessWidget {
  final int count;
  const SkeletonRoomCards({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Loading rooms',
        child: InsyncShimmer(
          child: Column(children: [
            for (var i = 0; i < count; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: SizedBox(
                  height: 104,
                  child: Row(children: [
                    _box(width: 128, height: 104, radius: 14),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _box(width: 150),
                            const SizedBox(height: 8),
                            _box(width: 100, height: 8),
                            const SizedBox(height: 8),
                            Row(children: [
                              for (var k = 0; k < 3; k++)
                                Padding(
                                    padding: const EdgeInsets.only(right: 3),
                                    child: _circle(16)),
                              const SizedBox(width: 6),
                              _box(width: 50, height: 8),
                            ]),
                          ]),
                    ),
                  ]),
                ),
              ),
          ]),
        ),
      );
}

/// A profile: big round photo, name lines, three stats, a photo grid.
class SkeletonProfile extends StatelessWidget {
  const SkeletonProfile({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Loading profile',
        child: InsyncShimmer(
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Row(children: [
                _circle(84),
                const SizedBox(width: 16),
                Expanded(
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        for (var i = 0; i < 3; i++)
                          Column(children: [
                            _box(width: 34, height: 14),
                            const SizedBox(height: 6),
                            _box(width: 48, height: 8),
                          ]),
                      ]),
                ),
              ]),
              const SizedBox(height: 14),
              Align(alignment: Alignment.centerLeft, child: _box(width: 160)),
              const SizedBox(height: 8),
              Align(
                  alignment: Alignment.centerLeft,
                  child: _box(width: 240, height: 8)),
              const SizedBox(height: 16),
              _box(height: 36, radius: 10),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 3,
                crossAxisSpacing: 3,
                children: [
                  for (var i = 0; i < 9; i++)
                    _box(height: double.infinity, radius: 4),
                ],
              ),
            ]),
          ),
        ),
      );
}
