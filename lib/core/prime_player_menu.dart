import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Prime Video's own player menu (Settings → Subtitles / Audio / Video
/// Quality), read and used from the room's settings sheet so a person
/// changes their own language, subtitles or quality without leaving the
/// room. Prime's page has no audio or subtitle tracks a script can switch,
/// and only shows its menu buttons when a real pointer moves over the
/// player, so one is moved there first (MainActivity.kt's
/// webview_pointer); the buttons themselves are then pressed by the page
/// script. Every step waits only until Prime's menu is ready. Only this
/// person's own player changes.
class PrimePlayerMenu {
  PrimePlayerMenu._();

  static const _pointer = MethodChannel('com.fling.app/webview_pointer');

  static Future<void> _wake() async {
    try {
      final ok = await _pointer.invokeMethod('hover');
      if (ok != true) debugPrint('OTT menu: no player to point at');
    } catch (e) {
      debugPrint('OTT menu: pointer failed: $e');
    }
  }

  static const _helpers = r"""
    var pl = document.getElementById('dv-web-player');
    if (!pl) return null;
    var wait = function(ms) { return new Promise(function(r) { setTimeout(r, ms); }); };
    async function until(f, ms) {
      var t0 = Date.now();
      while (Date.now() - t0 < ms) { var v = f(); if (v) return v; await wait(40); }
      return null;
    }
    function btn(label) { return pl.querySelector('button[aria-label="' + label + '"]'); }
    function menuOpen() { return !!(btn('Audio') || btn('Close')); }
    async function closeMenu() {
      for (var k = 0; k < 2 && menuOpen(); k++) {
        var c = btn('Close') || btn('Settings');
        if (!c) break;
        c.click();
        await until(function() { return !menuOpen(); }, 600);
      }
    }
    // One page of the menu (e.g. Audio), from the top each time: pressing
    // Settings again from a page closes the menu rather than going back.
    async function openPage(row, name) {
      await closeMenu();
      var s = await until(function() { return btn('Settings'); }, 1500);
      if (!s) return false;
      s.click();
      var b = await until(function() { return btn(row); }, 1000);
      if (!b) return false;
      b.click();
      return !!(await until(function() {
        return pl.querySelector('input[name="' + name + '"]');
      }, 1000));
    }
    function lines(el) {
      return (el.innerText || el.textContent || '').split('\n')
        .map(function(s) { return s.trim(); }).filter(Boolean);
    }
  """;

  /// {audio, text, quality}: each a list of {i, value, label, on}. All
  /// three pages in one go, while Prime's buttons are showing.
  static Future<Map<String, List<Map>>?> read(InAppWebViewController c) async {
    await _wake();
    try {
      final r = await c.callAsyncJavaScript(functionBody: '''
        $_helpers
        async function list(row, name, full) {
          if (!await openPage(row, name)) return null;
          return Array.from(pl.querySelectorAll('input[name="' + name + '"]'))
            .filter(function(i) { return i.value !== 'off'; })
            .map(function(i, k) {
              var l = lines(i.closest('label') || i.parentElement);
              return {i: k, value: i.value, on: i.checked,
                label: full ? l.slice(0, 2).join(' · ') : (l[0] || i.value)};
            });
        }
        var audio = await list('Audio', 'Audio', false);
        if (!audio) return null;
        var text = await list('Subtitles', 'subtitle', false) || [];
        var quality = await list('Video Quality', 'videoQuality', true) || [];
        await closeMenu();
        return {audio: audio, text: text, quality: quality};
      ''');
      final v = r?.value;
      if (v is! Map) {
        debugPrint('OTT menu: Prime: ${r?.error ?? 'menu not shown'}');
        return null;
      }
      List<Map> list(String k) =>
          ((v[k] as List?) ?? const []).whereType<Map>().toList();
      return {
        'audio': list('audio'),
        'text': list('text'),
        'quality': list('quality')
      };
    } catch (e) {
      debugPrint('OTT menu: Prime failed: $e');
      return null;
    }
  }

  /// Picks [value] in the menu [row] (e.g. 'Audio'), whose options are the
  /// inputs named [name]. 'off' turns subtitles off.
  static Future<bool> pick(InAppWebViewController c,
      {required String row,
      required String name,
      required String value}) async {
    await _wake();
    try {
      final r = await c.callAsyncJavaScript(functionBody: '''
        $_helpers
        if (!await openPage(row, name)) return false;
        var i = pl.querySelector('input[name="' + CSS.escape(name) + '"][value="' + CSS.escape(value) + '"]');
        if (i) {
          i.click();
          await until(function() { return i.checked; }, 800);
        }
        await closeMenu();
        return !!i;
      ''', arguments: {'row': row, 'name': name, 'value': value});
      if (r?.value != true) {
        debugPrint('OTT menu: Prime pick $row: ${r?.error ?? 'not done'}');
      }
      return r?.value == true;
    } catch (e) {
      debugPrint('OTT menu: Prime pick failed: $e');
      return false;
    }
  }
}
