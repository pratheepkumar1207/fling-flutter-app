import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';

import 'animated_emoji_bundled.dart';

// Animated emoji in chat: Google's Noto animated emoji (CC BY 4.0, credited
// in Settings → About). The most used ones are built into the app
// (assets/emoji/); the rest load from Google's emoji server the first time
// and are kept by the lottie cache. Emoji without an animation stay as
// normal text.

class AnimatedEmojiRegistry {
  AnimatedEmojiRegistry._();

  static const assetDir = 'assets/emoji/';
  static Map<String, String> _files = const {};
  static bool get isLoaded => _files.isNotEmpty;

  /// Reads the emoji → animation list. Call once at start-up.
  static Future<void> load() async {
    if (isLoaded) return;
    try {
      final raw = await rootBundle.loadString('${assetDir}manifest.json');
      final data = json.decode(raw) as Map<String, dynamic>;
      _files = {
        for (final e in data.entries)
          e.key: (e.value as Map)['file'] as String,
      };
    } catch (_) {
      // No list: every emoji simply stays as text.
    }
  }

  static String? fileFor(String emoji) =>
      _files[emoji] ?? _files[emoji.replaceAll('️', '')];

  static bool hasAnimation(String emoji) => fileFor(emoji) != null;
}

/// One animated emoji; plain text when it has no animation.
class AnimatedEmoji extends StatelessWidget {
  final String emoji;
  final double size;
  final bool repeat;
  const AnimatedEmoji(this.emoji,
      {super.key, this.size = 32, this.repeat = true});

  Widget _text() => Text(emoji,
      style: TextStyle(fontSize: size * 0.8, height: 1),
      textScaler: TextScaler.noScaling);

  @override
  Widget build(BuildContext context) {
    final file = AnimatedEmojiRegistry.fileFor(emoji);
    if (file == null) return _text();
    final code = file.replaceAll('.json', '');
    final child = kBundledEmojiFiles.contains(file)
        ? Lottie.asset('${AnimatedEmojiRegistry.assetDir}$file',
            repeat: repeat,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _text())
        : Lottie.network(
            'https://fonts.gstatic.com/s/e/notoemoji/latest/$code/lottie.json',
            repeat: repeat,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _text());
    return Semantics(
      label: emoji,
      excludeSemantics: true,
      child: SizedBox(width: size, height: size, child: child),
    );
  }
}

/// Swaps the emoji inside plain text spans (e.g. chat text with @mentions)
/// for animated ones that play once.
List<InlineSpan> animateEmojiSpans(List<InlineSpan> spans, double fontSize) {
  final out = <InlineSpan>[];
  for (final span in spans) {
    final text = span is TextSpan ? span.text : null;
    if (span is! TextSpan ||
        text == null ||
        span.children != null ||
        !text.characters.any(AnimatedEmojiRegistry.hasAnimation)) {
      out.add(span);
      continue;
    }
    final buf = StringBuffer();
    for (final c in text.characters) {
      if (AnimatedEmojiRegistry.hasAnimation(c)) {
        if (buf.isNotEmpty) {
          out.add(TextSpan(
              text: buf.toString(),
              style: span.style,
              recognizer: span.recognizer));
          buf.clear();
        }
        out.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: AnimatedEmoji(c, size: fontSize * 1.3, repeat: false),
        ));
      } else {
        buf.write(c);
      }
    }
    if (buf.isNotEmpty) {
      out.add(TextSpan(
          text: buf.toString(), style: span.style, recognizer: span.recognizer));
    }
  }
  return out;
}

/// Message text with animated emoji. A message of only 1–3 emoji shows them
/// big and playing; emoji inside normal text play once at text size.
class ChatEmojiText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final double bigSize;
  final int? maxLines;
  const ChatEmojiText(this.text,
      {super.key, this.style, this.bigSize = 64, this.maxLines});

  /// True when the message is only 1–3 animated emoji (shown big).
  static bool isBigEmoji(String text) {
    final chars =
        text.trim().characters.where((c) => c.trim().isNotEmpty).toList();
    return chars.isNotEmpty &&
        chars.length <= 3 &&
        chars.every(AnimatedEmojiRegistry.hasAnimation);
  }

  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style;
    if (isBigEmoji(text)) {
      final chars =
          text.trim().characters.where((c) => c.trim().isNotEmpty).toList();
      return Wrap(spacing: 2, children: [
        for (final c in chars) AnimatedEmoji(c, size: bigSize),
      ]);
    }
    if (!text.characters.any(AnimatedEmojiRegistry.hasAnimation)) {
      return Text(text, style: base, maxLines: maxLines);
    }
    final inline = (base.fontSize ?? 14) * 1.3;
    final spans = <InlineSpan>[];
    final buf = StringBuffer();
    for (final c in text.characters) {
      if (AnimatedEmojiRegistry.hasAnimation(c)) {
        if (buf.isNotEmpty) {
          spans.add(TextSpan(text: buf.toString()));
          buf.clear();
        }
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: AnimatedEmoji(c, size: inline, repeat: false),
        ));
      } else {
        buf.write(c);
      }
    }
    if (buf.isNotEmpty) spans.add(TextSpan(text: buf.toString()));
    return Text.rich(TextSpan(style: base, children: spans),
        maxLines: maxLines);
  }
}
