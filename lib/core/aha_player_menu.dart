import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Aha's player (video.js over dash.js 5): quality, audio and subtitles read
/// and switched through the player's own dash.js API, so the room's
/// settings sheet lists them and a person changes their own without leaving
/// the room — the same idea as hotstar_player_menu.dart. Only this person's
/// player changes.
class AhaPlayerMenu {
  AhaPlayerMenu._();

  static const _helpers = r"""
    var el = document.querySelector('.video-js');
    var p = el && el.player;
    var d = p && p._dashPlayer;
    function label(t, k) {
      var l = (t.labels || []).map(function(x) { return x.text || x; })[0];
      return l || t.lang || ('Track ' + (k + 1));
    }
    function auto() {
      try { return d.getSettings().streaming.abr.autoSwitchBitrate.video !== false; }
      catch (e) { return true; }
    }
  """;

  /// {audio, text, quality}: each a list of {i, value, label, on}.
  static Future<Map<String, List<Map>>?> read(InAppWebViewController c) async {
    try {
      final r = await c.callAsyncJavaScript(functionBody: '''
        $_helpers
        if (!d) return null;
        var quality = [], audio = [], text = [];
        try {
          var reps = d.getRepresentationsByType('video') || [];
          var cur = d.getCurrentRepresentationForType('video');
          var a = auto();
          if (reps.length > 1) quality.push({i: 0, value: 'auto', label: 'Auto', on: a});
          reps.map(function(r, k) { return {r: r, k: k}; })
            .sort(function(x, y) { return (y.r.height || 0) - (x.r.height || 0); })
            .forEach(function(x, n) {
              quality.push({
                i: n + 1, value: String(x.k),
                label: (x.r.height ? x.r.height + 'p' : Math.round((x.r.bandwidth || 0) / 1000) + ' kbps'),
                on: !a && cur && cur.id === x.r.id
              });
            });
        } catch (e) {}
        try {
          var at = d.getTracksFor('audio') || [];
          var ca = d.getCurrentTrackFor('audio');
          if (at.length > 1) at.forEach(function(t, k) {
            audio.push({i: k, value: String(k), label: label(t, k), on: !!ca && ca.id === t.id && ca.lang === t.lang});
          });
        } catch (e) {}
        try {
          var tt = d.getTracksFor('text') || [];
          var shown = d.isTextEnabled() ? d.getCurrentTextTrackIndex() : -1;
          tt.forEach(function(t, k) {
            text.push({i: k, value: String(k), label: label(t, k), on: shown === k});
          });
        } catch (e) {}
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

  /// Picks [value] (the index from [read], 'auto' for quality, 'Off' for
  /// subtitles) in [kind]: 'quality', 'audio' or 'text'.
  static Future<bool> pick(InAppWebViewController c,
      {required String kind, required String value}) async {
    try {
      final r = await c.callAsyncJavaScript(functionBody: '''
        $_helpers
        if (!d) return false;
        if (kind === 'quality') {
          if (value === 'auto') {
            d.updateSettings({streaming: {abr: {autoSwitchBitrate: {video: true}}}});
          } else {
            d.updateSettings({streaming: {abr: {autoSwitchBitrate: {video: false}}}});
            d.setRepresentationForTypeByIndex('video', parseInt(value, 10), true);
          }
          return true;
        }
        if (kind === 'audio') {
          var t = (d.getTracksFor('audio') || [])[parseInt(value, 10)];
          if (!t) return false;
          d.setCurrentTrack(t);
          return true;
        }
        if (value === 'Off' || value === 'off') {
          d.enableText(false);
          return true;
        }
        d.enableText(true);
        d.setTextTrack(parseInt(value, 10));
        return true;
      ''', arguments: {'kind': kind, 'value': value});
      return r?.value == true;
    } catch (_) {
      return false;
    }
  }
}
