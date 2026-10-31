import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Insync line icons — the exact set from the approved design: 24-unit grid,
/// 1.8 stroke, round caps and joins. Generated from the design source; keep
/// the paths in sync with it rather than hand-editing.
class InIconData {
  final String name;
  final String paths;
  const InIconData(this.name, this.paths);
}

class InIcons {
  InIcons._();
  static const home = InIconData('home',
      '<path d="M3.5 10.5L12 4l8.5 6.5V20a1 1 0 01-1 1H15v-6H9v6H4.5a1 1 0 01-1-1z"/>');
  static const feed = InIconData('feed',
      '<rect x="4" y="4" width="16" height="16" rx="4"/><path d="M8 9h8M8 13h8M8 17h5"/>');
  static const flame = InIconData('flame',
      '<path d="M12 21c-4 0-7-2.8-7-6.6 0-3.6 2.6-5.6 3.8-8.4.4 2 1.6 3.2 2.7 3.6C11.5 6.5 13 4.2 15.5 3c-.4 2.8.6 4.6 2 6.2 1.3 1.5 1.5 3 1.5 4.9C19 18 16 21 12 21z"/>');
  static const chat = InIconData(
      'chat', '<path d="M20 12a8 8 0 01-11.8 7L4 20l1.1-3.9A8 8 0 1120 12z"/>');
  static const plus = InIconData('plus', '<path d="M12 5v14M5 12h14"/>');
  static const bell = InIconData('bell',
      '<path d="M18 9.5a6 6 0 10-12 0c0 6-2.5 7.5-2.5 7.5h17S18 15.5 18 9.5z"/><path d="M10 20a2.2 2.2 0 004 0"/>');
  static const trophy = InIconData('trophy',
      '<path d="M8 4h8v5a4 4 0 01-8 0z"/><path d="M8 6H5a3 3 0 003 4M16 6h3a3 3 0 01-3 4M12 13v4M8.5 20h7M10 17h4"/>');
  static const search = InIconData(
      'search', '<circle cx="11" cy="11" r="6.5"/><path d="M20 20l-4.2-4.2"/>');
  static const back = InIconData('back', '<path d="M15 5l-7 7 7 7"/>');
  static const down = InIconData('down', '<path d="M6 9l6 6 6-6"/>');
  static const right = InIconData('right', '<path d="M9 5l7 7-7 7"/>');
  static const more = InIconData('more',
      '<circle cx="5" cy="12" r="1.2"/><circle cx="12" cy="12" r="1.2"/><circle cx="19" cy="12" r="1.2"/>');
  static const heart = InIconData('heart',
      '<path d="M12 20s-7.5-4.4-9-9.3C2 7.4 4.2 4.5 7.3 4.5c2 0 3.5 1.1 4.7 2.8 1.2-1.7 2.7-2.8 4.7-2.8 3.1 0 5.3 2.9 4.3 6.2C19.5 15.6 12 20 12 20z"/>');
  static const comment =
      InIconData('comment', '<path d="M4 5.5h16v10.5h-9l-5 4v-4H4z"/>');
  static const repeat = InIconData('repeat',
      '<path d="M17 3l3 3-3 3"/><path d="M20 6H8a4 4 0 00-4 4v1M7 21l-3-3 3-3"/><path d="M4 18h12a4 4 0 004-4v-1"/>');
  static const send = InIconData(
      'send', '<path d="M21 3L10 14"/><path d="M21 3l-7 18-4-7-7-4z"/>');
  static const bookmark =
      InIconData('bookmark', '<path d="M6 4h12v17l-6-4-6 4z"/>');
  static const mic = InIconData('mic',
      '<rect x="9" y="3" width="6" height="11" rx="3"/><path d="M5.5 11a6.5 6.5 0 0013 0M12 17.5V21"/>');
  static const micoff = InIconData('micoff',
      '<path d="M15 10V6a3 3 0 00-5.7-1.3M9 9v2a3 3 0 004.6 2.5M5.5 11a6.5 6.5 0 0010.8 4.9M18.5 11a6.4 6.4 0 01-.5 2.4M12 17.5V21M3 3l18 18"/>');
  static const video = InIconData('video',
      '<rect x="3" y="6" width="13" height="12" rx="3"/><path d="M16 10.5l5-3v9l-5-3z"/>');
  static const phone = InIconData('phone',
      '<path d="M5 4h3.5l1.5 4-2.2 1.4a11 11 0 005.8 5.8L15 13l4 1.5V18a2 2 0 01-2 2A15 15 0 013 6a2 2 0 012-2z"/>');
  static const phoneoff = InIconData('phoneoff',
      '<path d="M3.5 13.5c4.7-4.7 12.3-4.7 17 0l-2.2 2.6-3.3-1.4v-2.4a10 10 0 00-6 0v2.4l-3.3 1.4z"/>');
  static const gift = InIconData('gift',
      '<rect x="3.5" y="8" width="17" height="4" rx="1"/><path d="M5 12v8h14v-8M12 8v12M12 8C10 4 6.5 4.5 7.5 7c.4 1 2.5 1 4.5 1zm0 0c2-4 5.5-3.5 4.5-1-.4 1-2.5 1-4.5 1z"/>');
  static const gear = InIconData('gear',
      '<circle cx="12" cy="12" r="3"/><path d="M12 2.8l1.7 2.3 2.8-.6.6 2.8 2.3 1.7-1.2 2.6 1.2 2.6-2.3 1.7-.6 2.8-2.8-.6L12 21.2l-1.7-2.3-2.8.6-.6-2.8-2.3-1.7L5.8 12 4.6 9.4 6.9 7.7l.6-2.8 2.8.6z"/>');
  static const logout = InIconData('logout',
      '<path d="M14 4h4a2 2 0 012 2v12a2 2 0 01-2 2h-4M10 8l-4 4 4 4M6 12h10"/>');
  static const queue = InIconData(
      'queue', '<path d="M4 6h11M4 11h11M4 16h7"/><path d="M17 14v6l4-3z"/>');
  static const users = InIconData('users',
      '<circle cx="9" cy="8" r="3.5"/><path d="M2.5 20a6.5 6.5 0 0113 0"/><path d="M16 4.6a3.5 3.5 0 010 6.8M18.5 14a6.5 6.5 0 013 6"/>');
  static const useradd = InIconData('useradd',
      '<circle cx="10" cy="8" r="3.5"/><path d="M3.5 20a6.5 6.5 0 0113 0M19 8v6M16 11h6"/>');
  static const user = InIconData('user',
      '<circle cx="12" cy="8" r="4"/><path d="M4.5 21a7.5 7.5 0 0115 0"/>');
  static const lock = InIconData('lock',
      '<rect x="5" y="10.5" width="14" height="10" rx="2.5"/><path d="M8 10.5V7.5a4 4 0 018 0v3"/>');
  static const globe = InIconData('globe',
      '<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c2.5 2.6 3.6 5.6 3.6 9S14.5 18.4 12 21c-2.5-2.6-3.6-5.6-3.6-9S9.5 5.6 12 3z"/>');
  static const star = InIconData('star',
      '<path d="M12 3.5l2.6 5.4 5.9.8-4.3 4.1 1 5.8L12 16.8l-5.2 2.8 1-5.8-4.3-4.1 5.9-.8z"/>');
  static const close = InIconData('x', '<path d="M6 6l12 12M18 6L6 18"/>');
  static const undo = InIconData('undo',
      '<path d="M9 14L4 9l5-5"/><path d="M4 9h10.5a5.5 5.5 0 010 11H11"/>');
  static const tune = InIconData('tune',
      '<path d="M4 7h10M18 7h2M4 17h4M12 17h8"/><circle cx="16" cy="7" r="2"/><circle cx="10" cy="17" r="2"/>');
  static const map = InIconData('map',
      '<path d="M9 4L3.5 6v14L9 18l6 2 5.5-2V4L15 6z"/><path d="M9 4v14M15 6v14"/>');
  static const dice = InIconData('dice',
      '<rect x="4" y="4" width="16" height="16" rx="4"/><circle cx="9" cy="9" r="1.2"/><circle cx="15" cy="15" r="1.2"/><circle cx="15" cy="9" r="1.2"/><circle cx="9" cy="15" r="1.2"/>');
  static const play = InIconData('play', '<path d="M8 5.5v13l10.5-6.5z"/>');
  static const pause = InIconData('pause', '<path d="M8 5v14M16 5v14"/>');
  static const back10 = InIconData('back10',
      '<path d="M4 12a8 8 0 108-8H8"/><path d="M10 1.5L7.5 4 10 6.5"/><path d="M9.5 10v5M12.5 10h2v5h-2z"/>');
  static const forward10 = InIconData('fwd10',
      '<path d="M20 12a8 8 0 11-8-8h4"/><path d="M14 1.5L16.5 4 14 6.5"/><path d="M9.5 10v5M12.5 10h2v5h-2z"/>');
  static const music = InIconData('music',
      '<path d="M9 18V5l11-2v13"/><circle cx="6.5" cy="18" r="2.5"/><circle cx="17.5" cy="16" r="2.5"/>');
  static const game = InIconData('game',
      '<path d="M7 7h10a4.5 4.5 0 014.4 5.4l-.9 4.4a2.5 2.5 0 01-4.3 1.2L14 16h-4l-2.2 2a2.5 2.5 0 01-4.3-1.2l-.9-4.4A4.5 4.5 0 017 7z"/><path d="M8 10.5v3M6.5 12h3M15.5 11h.01M17.5 13h.01"/>');
  static const tv = InIconData('tv',
      '<rect x="3" y="5" width="18" height="12" rx="3"/><path d="M8 21h8M10 9.5v4l3.5-2z"/>');
  static const camera = InIconData('camera',
      '<path d="M4 8h3l2-2.5h6L17 8h3v11H4z"/><circle cx="12" cy="13" r="3.5"/>');
  static const flip = InIconData('flip',
      '<path d="M4 8h3l2-2.5h6L17 8h3v11H4z"/><path d="M9 12.5a3 3 0 015-1.5M15 13.5a3 3 0 01-5 1.5M14 9.5v1.5h-1.5M10 16.5V15h1.5"/>');
  static const image = InIconData('image',
      '<rect x="3.5" y="4.5" width="17" height="15" rx="3"/><circle cx="9" cy="10" r="1.8"/><path d="M20.5 16l-5-5-9 8.5"/>');
  static const gif = InIconData('gif',
      '<rect x="3" y="5" width="18" height="14" rx="3"/><path d="M10 10H8v4h2v-2M13 10v4M16.5 10H15v4M15 12h1.3"/>');
  static const smile = InIconData('smile',
      '<circle cx="12" cy="12" r="9"/><path d="M8.5 14a4 4 0 007 0M9 9.5h.01M15 9.5h.01"/>');
  static const sticker = InIconData('sticker',
      '<path d="M20 12V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2h6z"/><path d="M12 20a8 8 0 018-8M9 9.5h.01M15 9.5h.01"/>');
  static const clip = InIconData('clip',
      '<path d="M20 11.5l-8 8a5 5 0 01-7-7l8.5-8.5a3.3 3.3 0 014.7 4.7L9.7 17.2a1.7 1.7 0 01-2.4-2.4l7.6-7.6"/>');
  static const link = InIconData('link',
      '<path d="M10 14a4 4 0 005.7 0l3-3a4 4 0 00-5.7-5.7l-1 1"/><path d="M14 10a4 4 0 00-5.7 0l-3 3a4 4 0 005.7 5.7l1-1"/>');
  static const blend = InIconData('blend',
      '<circle cx="9" cy="12" r="5.5"/><circle cx="15" cy="12" r="5.5"/>');
  static const sync = InIconData('sync',
      '<path d="M20 11a8 8 0 00-14.3-4.3L4 9M4 4v5h5"/><path d="M4 13a8 8 0 0014.3 4.3L20 15M20 20v-5h-5"/>');
  static const check = InIconData('check', '<path d="M5 12.5l4.5 4.5L19 7"/>');
  static const crown =
      InIconData('crown', '<path d="M3.5 8l4.5 4 4-7 4 7 4.5-4-2 11h-13z"/>');
  static const wheel = InIconData('wheel',
      '<circle cx="12" cy="12" r="8.5"/><path d="M12 3.5v17M3.5 12h17M6 6l12 12M18 6L6 18"/><circle cx="12" cy="12" r="2" fill="currentColor"/>');
  static const ticket = InIconData('ticket',
      '<path d="M4 7a2 2 0 012-2h12a2 2 0 012 2v2.5a2.5 2.5 0 000 5V17a2 2 0 01-2 2H6a2 2 0 01-2-2v-2.5a2.5 2.5 0 000-5z"/><path d="M14 5v14" stroke-dasharray="2 2"/>');
  static const live = InIconData('live',
      '<circle cx="12" cy="12" r="2.5"/><path d="M7.8 7.8a6 6 0 000 8.4M16.2 7.8a6 6 0 010 8.4M5 5a10 10 0 000 14M19 5a10 10 0 010 14"/>');
  static const chart =
      InIconData('chart', '<path d="M4 20V10M10 20V4M16 20v-7M21 20H3"/>');
  static const shield = InIconData('shield',
      '<path d="M12 3l7.5 3v5.5c0 4.6-3.2 8.3-7.5 9.5-4.3-1.2-7.5-4.9-7.5-9.5V6z"/><path d="M8.8 12l2.2 2.2 4.2-4.4"/>');
  static const reply = InIconData('reply',
      '<path d="M9 14L4 9l5-5"/><path d="M4 9h10.5a5.5 5.5 0 010 11H11"/>');
  static const shuffle = InIconData('shuffle',
      '<path d="M3 7h3.5c2 0 3.4 1 4.5 2.6l2 2.8c1.1 1.6 2.5 2.6 4.5 2.6H21M3 17h3.5c1.3 0 2.4-.4 3.3-1.2M13.7 8.2C14.6 7.4 15.7 7 17 7h4M18 4l3 3-3 3M18 14l3 3-3 3"/>');
  static const eye = InIconData('eye',
      '<path d="M3 12s3.5-7 9-7 9 7 9 7-3.5 7-9 7-9-7-9-7z"/><circle cx="12" cy="12" r="3"/>');
  static const eyeoff = InIconData('eyeoff',
      '<path d="M10.6 5.1A9.5 9.5 0 0112 5c5.5 0 9 7 9 7a16 16 0 01-2.5 3.3M6.6 6.6C4.3 8.2 3 12 3 12s3.5 7 9 7a9 9 0 004.4-1.1M3 3l18 18M9.9 9.9a3 3 0 004.2 4.2"/>');
  static const block = InIconData(
      'block', '<circle cx="12" cy="12" r="9"/><path d="M5.6 5.6l12.8 12.8"/>');
  static const help = InIconData('help',
      '<circle cx="12" cy="12" r="9"/><path d="M9.5 9.5a2.5 2.5 0 114 2c-1 .6-1.5 1.2-1.5 2.3M12 17h.01"/>');
  static const info = InIconData('info',
      '<circle cx="12" cy="12" r="9"/><path d="M12 11v5.5M12 7.5h.01"/>');
  static const doc = InIconData(
      'doc', '<path d="M6 3h8l4 4v14H6z"/><path d="M14 3v4h4M9 12h6M9 16h6"/>');
  static const pin = InIconData('pin',
      '<path d="M12 21s-6.5-6-6.5-11a6.5 6.5 0 0113 0c0 5-6.5 11-6.5 11z"/><circle cx="12" cy="10" r="2.5"/>');
  static const lang = InIconData('lang',
      '<path d="M4 5h9M8.5 3v2M6 5c.5 3.5 3 6.5 6 8M11 5c-.5 3-3 6.5-7 8.5"/><path d="M13 21l4-9 4 9M14.3 18h5.4"/>');
  static const calendar = InIconData('calendar',
      '<rect x="3.5" y="5" width="17" height="15.5" rx="3"/><path d="M3.5 10h17M8 3v4M16 3v4"/>');
  static const menu = InIconData('menu', '<path d="M4 7h16M4 12h16M4 17h16"/>');
  static const archive = InIconData('archive',
      '<rect x="3" y="4" width="18" height="5" rx="1.5"/><path d="M5 9v10a1 1 0 001 1h12a1 1 0 001-1V9M10 13h4"/>');
  static const spark = InIconData('spark',
      '<path d="M12 3l1.8 5.2L19 10l-5.2 1.8L12 17l-1.8-5.2L5 10l5.2-1.8zM19 16l.8 2.2L22 19l-2.2.8L19 22l-.8-2.2L16 19l2.2-.8z"/>');
  static const verified = InIconData('verified',
      '<path d="M12 2.5l2.4 1.8 3-.2.9 2.8 2.5 1.7-1 2.9 1 2.9-2.5 1.7-.9 2.8-3-.2L12 21.5l-2.4-1.8-3 .2-.9-2.8-2.5-1.7 1-2.9-1-2.9 2.5-1.7.9-2.8 3 .2z"/><path d="M8.5 12l2.4 2.4 4.6-4.8"/>');
  static const wallet = InIconData('wallet',
      '<path d="M4 7a2 2 0 012-2h11v4"/><rect x="3.5" y="7" width="17" height="13" rx="3"/><path d="M16 13.5h.01"/>');
  static const cash = InIconData('cash',
      '<rect x="3" y="6" width="18" height="12" rx="3"/><circle cx="12" cy="12" r="2.5"/><path d="M6.5 9.5h.01M17.5 14.5h.01"/>');
  static const arrowup =
      InIconData('arrowup', '<path d="M12 19V5M6 11l6-6 6 6"/>');
  static const arrowdn =
      InIconData('arrowdn', '<path d="M12 5v14M6 13l6 6 6-6"/>');
  static const badge = InIconData('badge',
      '<circle cx="12" cy="9" r="5.5"/><path d="M8.5 13.5L7 21l5-2.5 5 2.5-1.5-7.5"/>');
  static const target = InIconData('target',
      '<circle cx="12" cy="12" r="8.5"/><circle cx="12" cy="12" r="4.5"/><circle cx="12" cy="12" r="1" fill="currentColor"/>');
  static const community = InIconData('community',
      '<circle cx="12" cy="7" r="3"/><circle cx="5" cy="15" r="2.5"/><circle cx="19" cy="15" r="2.5"/><path d="M8 21a4 4 0 018 0M12 10v3M7 13.5l3-1.5M17 13.5l-3-1.5"/>');
  static const share = InIconData('share',
      '<circle cx="18" cy="5.5" r="2.5"/><circle cx="6" cy="12" r="2.5"/><circle cx="18" cy="18.5" r="2.5"/><path d="M8.2 10.8l7.6-4M8.2 13.2l7.6 4"/>');
  static const speaker = InIconData('speaker',
      '<path d="M4 9.5h3.5L12 5.5v13L7.5 14.5H4z"/><path d="M15.5 9a4 4 0 010 6M18 6.5a7.5 7.5 0 010 11"/>');
  static const cam = InIconData('cam', '<path d="M3 6.5h12v11H3z"/>');
  static const drive = InIconData('drive',
      '<path d="M8.5 4h7l5.5 9.5-3.5 6h-11L3 13.5z"/><path d="M8.5 4l5.5 9.5H21M15.5 4L10 13.5l-3.5 6M3 13.5h11"/>');
  static const cloud = InIconData('cloud',
      '<path d="M7 18.5a4.5 4.5 0 01-.6-9A6 6 0 0118 8.5a5 5 0 01-1 10z"/>');
  static const remote = InIconData('remote',
      '<rect x="7.5" y="2.5" width="9" height="19" rx="3"/><circle cx="12" cy="8" r="1.8"/><path d="M10.5 13h.01M13.5 13h.01M10.5 16h.01M13.5 16h.01"/>');
  static const wave = InIconData(
      'wave', '<path d="M3 12h2M7 8v8M11 5v14M15 9v6M19 7v10M21 12h0"/>');
  static const poll = InIconData('poll',
      '<rect x="4" y="4" width="16" height="16" rx="4"/><path d="M8 15v-3M12 15V8M16 15v-5"/>');
  static const mute = InIconData('mute',
      '<path d="M4 9.5h3.5L12 5.5v13L7.5 14.5H4zM16 9.5l5 5M21 9.5l-5 5"/>');
  static const chev = InIconData('chev', '<path d="M9 6l6 6-6 6"/>');
  static const qr = InIconData('qr',
      '<rect x="4" y="4" width="6" height="6" rx="1"/><rect x="14" y="4" width="6" height="6" rx="1"/><rect x="4" y="14" width="6" height="6" rx="1"/><path d="M14 14h2v2h-2zM18 14h2M14 18h2M18 18h2v2"/>');
  static const streak = InIconData('streak',
      '<path d="M12 21c-4 0-7-2.8-7-6.6 0-3.6 2.6-5.6 3.8-8.4.4 2 1.6 3.2 2.7 3.6C11.5 6.5 13 4.2 15.5 3c-.4 2.8.6 4.6 2 6.2 1.3 1.5 1.5 3 1.5 4.9C19 18 16 21 12 21z"/>');
  static const mail = InIconData('mail',
      '<rect x="3" y="5" width="18" height="14" rx="3"/><path d="M4 7l8 6 8-6"/>');
  static const reel = InIconData('reel',
      '<rect x="4" y="3" width="16" height="18" rx="4"/><path d="M4 8h16M9 3l2 5M14 3l2 5M10.5 12v5l4-2.5z"/>');
  static const film = InIconData('film',
      '<rect x="3.5" y="4" width="17" height="16" rx="3"/><path d="M8 4v16M16 4v16M3.5 9H8M3.5 15H8M16 9h4.5M16 15h4.5"/>');
  static const swap = InIconData(
      'swap', '<path d="M7 4L3 8l4 4M3 8h14M17 20l4-4-4-4M21 16H7"/>');
  static const hash =
      InIconData('hash', '<path d="M5 9h14M4 15h14M10 4L8 20M16 4l-2 16"/>');

  static const edit = InIconData('edit',
      '<path d="M4 20h4L19 9a2.8 2.8 0 00-4-4L4 16z"/><path d="M13.5 6.5l4 4"/>');
  static const copy = InIconData('copy',
      '<rect x="8" y="8" width="12" height="12" rx="3"/><path d="M16 8V6a2 2 0 00-2-2H6a2 2 0 00-2 2v8a2 2 0 002 2h2"/>');
  static const fullscreen = InIconData('fullscreen',
      '<path d="M4 9V5a1 1 0 011-1h4M15 4h4a1 1 0 011 1v4M20 15v4a1 1 0 01-1 1h-4M9 20H5a1 1 0 01-1-1v-4"/>');
  static const pip = InIconData('pip',
      '<rect x="3" y="5" width="18" height="14" rx="3"/><rect x="12" y="11" width="6" height="5" rx="1.5"/>');
  static const bolt =
      InIconData('bolt', '<path d="M13 3L5 13.5h6L10 21l8-10.5h-6z"/>');
  static const skipNext = InIconData(
      'skipNext', '<path d="M6 5.5v13l9-6.5z"/><path d="M18 5v14"/>');
  static const skipPrev = InIconData(
      'skipPrev', '<path d="M18 5.5v13l-9-6.5z"/><path d="M6 5v14"/>');
  static const hourglass = InIconData('hourglass',
      '<path d="M7 3h10M7 21h10M8 3c0 5 8 5 8 9s-8 4-8 9M16 3c0 5-8 5-8 9s8 4 8 9"/>');
  static const external = InIconData('external',
      '<path d="M14 4h6v6M20 4l-9 9"/><path d="M18 14v4a2 2 0 01-2 2H6a2 2 0 01-2-2V8a2 2 0 012-2h4"/>');
  static const bank = InIconData('bank',
      '<path d="M3 10l9-6 9 6M5 10v8M9.5 10v8M14.5 10v8M19 10v8M3 20h18"/>');
  static const diamond = InIconData('diamond',
      '<path d="M7 4h10l4 5.5L12 20 3 9.5z"/><path d="M3 9.5h18M9.5 4L8 9.5l4 10.5 4-10.5L14.5 4"/>');
  static const swords = InIconData('swords',
      '<path d="M4 4l10 10M4 4h4M4 4v4M20 4L10 14M20 4h-4M20 4v4"/><path d="M12.5 15.5l-4 4M7 13l4 4M11.5 15.5l4 4M17 13l-4 4"/>');

  /// Icons that render solid when [InIcon.filled] is set.
  static const filledNames = {
    'bookmark',
    'crown',
    'heart',
    'play',
    'star',
    'skipNext',
    'skipPrev',
    'bolt',
    'diamond'
  };
}

class InIcon extends StatelessWidget {
  final InIconData icon;
  final double size;
  final Color? color;
  final bool filled;
  final String? semanticLabel;

  /// Soft drop shadows, for icons sitting on video or photos.
  final List<Shadow>? shadows;
  const InIcon(this.icon,
      {super.key,
      this.size = 22,
      this.color,
      this.filled = false,
      this.shadows,
      this.semanticLabel});

  @override
  Widget build(BuildContext context) {
    final c = color ?? IconTheme.of(context).color ?? const Color(0xFFF4F4F6);
    final hex =
        '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    final fill =
        filled && InIcons.filledNames.contains(icon.name) ? hex : 'none';
    final svg =
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="$fill" '
        'stroke="$hex" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">'
        '${icon.paths.replaceAll('currentColor', hex)}</svg>';
    // Align keeps the icon at [size] even when a parent forces a bigger
    // box (input prefix slots, list tile leading, etc.).
    final picture = Align(
      widthFactor: 1,
      heightFactor: 1,
      child: SizedBox(
        width: size,
        height: size,
        child: Opacity(
          opacity: c.a,
          child: SvgPicture.string(svg,
              width: size, height: size, semanticsLabel: semanticLabel),
        ),
      ),
    );
    final shadowList = shadows;
    if (shadowList == null || shadowList.isEmpty) return picture;
    return Stack(clipBehavior: Clip.none, children: [
      for (final sh in shadowList)
        Transform.translate(
          offset: sh.offset,
          child: ImageFiltered(
            imageFilter:
                ImageFilter.blur(sigmaX: sh.blurSigma, sigmaY: sh.blurSigma),
            child: ExcludeSemantics(
              child: InIcon(icon, size: size, color: sh.color, filled: filled),
            ),
          ),
        ),
      picture,
    ]);
  }
}
