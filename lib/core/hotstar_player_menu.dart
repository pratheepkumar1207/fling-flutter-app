import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Hotstar's own player menus (Quality, and Audio & Subtitles), read and
/// used from the room's settings sheet so a person changes their own
/// quality, language or subtitles without leaving the room — the same idea
/// as prime_player_menu.dart. Hotstar's buttons answer a page script's
/// press, so no pointer is needed. The menus open behind the room's
/// full-screen video, so nothing flashes. Only this person's player
/// changes.
class HotstarPlayerMenu {
  HotstarPlayerMenu._();

  static const _helpers = r"""
    var wait = function(ms) { return new Promise(function(r) { setTimeout(r, ms); }); };
    function menu(t) {
      return Array.from(document.querySelectorAll('button[data-testid="player-menu"]'))
        .find(function(b) { return b.textContent.trim().indexOf(t) === 0; });
    }
    // The choices in whichever menu is open; the ticked one is in bold.
    function opts() {
      return Array.from(document.querySelectorAll('button'))
        .filter(function(b) {
          return b.querySelector('.BUTTON3_SEMIBOLD, .BUTTON3_MEDIUM') &&
            !b.getAttribute('data-testid') && !/Report an Issue/.test(b.textContent);
        });
    }
    function on(b) { return !!b.querySelector('.BUTTON3_SEMIBOLD'); }
    // AUDIO or SUBTITLES for a choice in the Audio & Subtitles menu.
    function group(b) {
      var p = b.parentElement;
      for (var i = 0; i < 6 && p; i++) {
        var t = (p.innerText || '').split('\n')[0].trim();
        if (t === 'AUDIO' || t === 'SUBTITLES') return t;
        p = p.parentElement;
      }
      return '';
    }
    async function openMenu(t, isOpen) {
      var m = menu(t);
      if (!m) return null;
      if (!isOpen()) { m.click(); await wait(600); }
      return m;
    }
    function qualityOpen() { return opts().some(function(b) { return group(b) === ''; }); }
    function audioOpen() { return opts().some(function(b) { return group(b) !== ''; }); }
  """;

  /// {audio, text, quality}: each a list of {i, value, label, on}.
  static Future<Map<String, List<Map>>?> read(InAppWebViewController c) async {
    try {
      final r = await c.callAsyncJavaScript(functionBody: '''
        $_helpers
        if (!menu('Quality') && !menu('Audio')) return null;
        function pack(list) {
          return list.map(function(b, k) {
            var t = b.textContent.trim();
            return {i: k, value: t, label: t, on: on(b)};
          });
        }
        var quality = [], audio = [], text = [];
        var q = await openMenu('Quality', qualityOpen);
        if (q) {
          quality = pack(opts().filter(function(b) { return group(b) === ''; }));
          if (qualityOpen()) { q.click(); await wait(300); }
        }
        var a = await openMenu('Audio', audioOpen);
        if (a) {
          audio = pack(opts().filter(function(b) { return group(b) === 'AUDIO'; }));
          text = pack(opts().filter(function(b) {
            return group(b) === 'SUBTITLES' && b.textContent.trim() !== 'Off';
          }));
          if (audioOpen()) { a.click(); await wait(300); }
        }
        return {audio: audio, text: text, quality: quality};
      ''');
      final v = r?.value;
      if (v is! Map) return null;
      List<Map> list(String k) =>
          ((v[k] as List?) ?? const []).whereType<Map>().toList();
      return {
        'audio': list('audio'),
        'text': list('text'),
        'quality': list('quality')
      };
    } catch (_) {
      return null;
    }
  }

  /// Picks the choice called [value] in [kind]: 'quality', 'audio' or
  /// 'text' ('Off' turns subtitles off).
  static Future<bool> pick(InAppWebViewController c,
      {required String kind, required String value}) async {
    try {
      final r = await c.callAsyncJavaScript(functionBody: '''
        $_helpers
        var want = kind === 'audio' ? 'AUDIO' : kind === 'text' ? 'SUBTITLES' : '';
        var m = kind === 'quality'
          ? await openMenu('Quality', qualityOpen)
          : await openMenu('Audio', audioOpen);
        if (!m) return false;
        var b = opts().find(function(o) {
          return group(o) === want && o.textContent.trim() === value;
        });
        if (b) { b.click(); await wait(600); }
        // Close it again if picking didn't.
        if (kind === 'quality' ? qualityOpen() : audioOpen()) { m.click(); await wait(300); }
        return !!b;
      ''', arguments: {'kind': kind, 'value': value});
      return r?.value == true;
    } catch (_) {
      return false;
    }
  }
}
