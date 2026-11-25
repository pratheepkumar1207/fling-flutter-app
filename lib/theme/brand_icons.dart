import 'package:flutter/widgets.dart';

/// The six brand logos the app shows (share, invite and watch sources).
/// Glyphs from Font Awesome Free Brands (assets/fonts/brand-icons.otf, see
/// BRAND_ICONS_LICENSE.txt next to it). Release builds keep only these
/// glyphs, so the font costs about 2 KB.
abstract final class BrandIcons {
  static const _font = 'BrandIcons';
  static const whatsapp = IconData(0xf232, fontFamily: _font);
  static const instagram = IconData(0xf16d, fontFamily: _font);
  static const telegram = IconData(0xf2c6, fontFamily: _font);
  static const chrome = IconData(0xf268, fontFamily: _font);
  static const googleDrive = IconData(0xf3aa, fontFamily: _font);
  static const xTwitter = IconData(0xe61b, fontFamily: _font);
}
