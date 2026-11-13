import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Quality, audio and subtitles for OTT sites built on the common web
/// players: hls.js (Sun NXT, Airtel Xstream…), shaka and dash.js. A script
/// that runs before the site ([playerHookScript]) notes each player the page
/// creates; [read] lists that player's choices and [pick] switches one, so
/// the room's settings sheet works on these sites like on Prime and
/// Hotstar. Only this person's player changes.
class WebPlayerMenu {
  WebPlayerMenu._();

  /// Keeps hold of the players the page makes, in window.__insyncPlayers.
  static final playerHookScript = UserScript(
    injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
    forMainFrameOnly: false,
    source: r'''
(function () {
  try {
    var list = window.__insyncPlayers = window.__insyncPlayers || [];
    function note(kind, p) {
      if (!p || list.some(function (x) { return x.p === p; })) return;
      list.push({ kind: kind, p: p });
      if (list.length > 6) list.shift();
    }
    function hookHls(H) {
      if (!H || !H.prototype || H.__insync) return;
      H.__insync = true;
      ['attachMedia', 'loadSource'].forEach(function (m) {
        var f = H.prototype[m];
        if (typeof f === 'function') H.prototype[m] = function () { note('hls', this); return f.apply(this, arguments); };
      });
    }
    function hookShaka(s) {
      var P = s && s.Player;
      if (!P || !P.prototype || P.__insync) return;
      P.__insync = true;
      ['load', 'attach'].forEach(function (m) {
        var f = P.prototype[m];
        if (typeof f === 'function') P.prototype[m] = function () { note('shaka', this); return f.apply(this, arguments); };
      });
    }
    function hookDash(d) {
      if (!d || !d.MediaPlayer || d.__insync) return;
      d.__insync = true;
      var MP = d.MediaPlayer;
      d.MediaPlayer = function () {
        var factory = MP.apply(this, arguments);
        var create = factory.create;
        factory.create = function () { var pl = create.apply(this, arguments); note('dash', pl); return pl; };
        return factory;
      };
    }
    function trap(name, hook) {
      var cur = window[name];
      if (cur) { hook(cur); return; }
      try {
        Object.defineProperty(window, name, {
          configurable: true,
          get: function () { return cur; },
          set: function (v) { cur = v; try { hook(v); } catch (e) {} }
        });
      } catch (e) {}
    }
    trap('Hls', hookHls);
    trap('shaka', hookShaka);
    trap('dashjs', hookDash);
  } catch (e) {}
})();
''',
  );

  // Finds the live player: hls.js, shaka or dash.js (incl. Aha's video.js).
  static const _find = r"""
    function find() {
      var list = (window.__insyncPlayers || []).slice().reverse();
      for (var i = 0; i < list.length; i++) {
        var x = list[i];
        if (x.kind === 'hls' && x.p.media) return x;
        if (x.kind === 'shaka' && x.p.getMediaElement && x.p.getMediaElement()) return x;
        if (x.kind === 'dash') return x;
      }
      var el = document.querySelector('.video-js');
      if (el && el.player && el.player._dashPlayer) return { kind: 'dash', p: el.player._dashPlayer };
      return null;
    }
    function name(t, k) {
      var l = t && ((t.labels || []).map(function (x) { return x.text || x; })[0] || t.name || t.label || t.lang || t.language);
      return l || ('Track ' + (k + 1));
    }
  """;

  /// {audio, text, quality}: each a list of {i, value, label, on}; null when
  /// the page has none of these players.
  static Future<Map<String, List<Map>>?> read(InAppWebViewController c) async {
    try {
      final r = await c.callAsyncJavaScript(functionBody: '''
        $_find
        var x = find();
        if (!x) return null;
        var p = x.p, quality = [], audio = [], text = [];
        function addQualities(levels, auto, isOn) {
          if (levels.length < 2) return;
          quality.push({ i: 0, value: 'auto', label: 'Auto', on: auto });
          levels.slice().sort(function (a, b) { return (b.h || 0) - (a.h || 0); })
            .forEach(function (l, n) {
              quality.push({ i: n + 1, value: String(l.v), label: l.h ? l.h + 'p' : Math.round((l.bw || 0) / 1000) + ' kbps', on: !auto && isOn(l) });
            });
        }
        if (x.kind === 'hls') {
          var lv = (p.levels || []).map(function (l, k) { return { v: k, h: l.height, bw: l.bitrate }; });
          var hAuto = p.autoLevelEnabled !== undefined ? p.autoLevelEnabled : p.currentLevel === -1;
          addQualities(lv, hAuto, function (l) { return l.v === p.currentLevel; });
          var at = p.audioTracks || [];
          if (at.length > 1) at.forEach(function (t, k) { audio.push({ i: k, value: String(k), label: name(t, k), on: p.audioTrack === k }); });
          (p.subtitleTracks || []).forEach(function (t, k) { text.push({ i: k, value: String(k), label: name(t, k), on: p.subtitleTrack === k && p.subtitleDisplay !== false }); });
        } else if (x.kind === 'shaka') {
          var vts = p.getVariantTracks() || [];
          var act = vts.filter(function (t) { return t.active; })[0];
          var seen = {}, sl = [];
          vts.forEach(function (t) {
            if (act && t.language !== act.language) return;
            if (!t.height || seen[t.height]) return;
            seen[t.height] = 1; sl.push({ v: t.id, h: t.height, bw: t.bandwidth });
          });
          var sAuto = p.getConfiguration().abr.enabled;
          addQualities(sl, sAuto, function (l) { return act && act.height === l.h; });
          var langs = [];
          vts.forEach(function (t) { if (t.language && langs.indexOf(t.language) < 0) langs.push(t.language); });
          if (langs.length > 1) langs.forEach(function (l, k) { audio.push({ i: k, value: l, label: l, on: !!act && act.language === l }); });
          var vis = p.isTextTrackVisible();
          (p.getTextTracks() || []).forEach(function (t, k) { text.push({ i: k, value: String(t.id), label: name(t, k), on: vis && t.active }); });
        } else {
          var reps = p.getRepresentationsByType ? (p.getRepresentationsByType('video') || []) : [];
          var cur = p.getCurrentRepresentationForType ? p.getCurrentRepresentationForType('video') : null;
          var dAuto = true;
          try { dAuto = p.getSettings().streaming.abr.autoSwitchBitrate.video !== false; } catch (e) {}
          addQualities(reps.map(function (r, k) { return { v: k, h: r.height, bw: r.bandwidth, id: r.id }; }), dAuto,
            function (l) { return cur && cur.id === l.id; });
          var dat = p.getTracksFor('audio') || [], ca = p.getCurrentTrackFor('audio');
          if (dat.length > 1) dat.forEach(function (t, k) { audio.push({ i: k, value: String(k), label: name(t, k), on: !!ca && ca.id === t.id && ca.lang === t.lang }); });
          var shown = p.isTextEnabled() ? p.getCurrentTextTrackIndex() : -1;
          (p.getTracksFor('text') || []).forEach(function (t, k) { text.push({ i: k, value: String(k), label: name(t, k), on: shown === k }); });
        }
        return { audio: audio, text: text, quality: quality };
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

  /// Picks [value] from [read] in [kind]: 'quality' ('auto' for Auto),
  /// 'audio' or 'text' ('Off' turns subtitles off).
  static Future<bool> pick(InAppWebViewController c,
      {required String kind, required String value}) async {
    try {
      final r = await c.callAsyncJavaScript(functionBody: '''
        $_find
        var x = find();
        if (!x) return false;
        var p = x.p, off = value === 'Off' || value === 'off', n = parseInt(value, 10);
        if (x.kind === 'hls') {
          if (kind === 'quality') { p.currentLevel = value === 'auto' ? -1 : n; return true; }
          if (kind === 'audio') { p.audioTrack = n; return true; }
          if (off) { p.subtitleTrack = -1; return true; }
          p.subtitleDisplay = true; p.subtitleTrack = n; return true;
        }
        if (x.kind === 'shaka') {
          if (kind === 'quality') {
            if (value === 'auto') { p.configure({ abr: { enabled: true } }); return true; }
            var t = (p.getVariantTracks() || []).filter(function (v) { return v.id === n; })[0];
            if (!t) return false;
            p.configure({ abr: { enabled: false } });
            p.selectVariantTrack(t, true);
            return true;
          }
          if (kind === 'audio') { p.selectAudioLanguage(value); return true; }
          if (off) { p.setTextTrackVisibility(false); return true; }
          var tt = (p.getTextTracks() || []).filter(function (v) { return v.id === n; })[0];
          if (!tt) return false;
          p.selectTextTrack(tt); p.setTextTrackVisibility(true); return true;
        }
        if (kind === 'quality') {
          if (value === 'auto') { p.updateSettings({ streaming: { abr: { autoSwitchBitrate: { video: true } } } }); return true; }
          p.updateSettings({ streaming: { abr: { autoSwitchBitrate: { video: false } } } });
          p.setRepresentationForTypeByIndex('video', n, true);
          return true;
        }
        if (kind === 'audio') { var at = (p.getTracksFor('audio') || [])[n]; if (!at) return false; p.setCurrentTrack(at); return true; }
        if (off) { p.enableText(false); return true; }
        p.enableText(true); p.setTextTrack(n); return true;
      ''', arguments: {'kind': kind, 'value': value});
      return r?.value == true;
    } catch (_) {
      return false;
    }
  }
}
