import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A listener's own room preferences (the guest settings sheet), kept on
/// this device: push to talk, the voices-vs-video balance and auto
/// picture-in-picture. Nothing here changes the room for anyone else.
class RoomPrefs extends ChangeNotifier {
  RoomPrefs._();
  static final instance = RoomPrefs._();

  static const _kPtt = 'room.pushToTalk';
  static const _kBalance = 'room.voiceVideoBalance';
  static const _kPip = 'room.autoPip';

  bool _loaded = false;
  bool pushToTalk = false;

  /// 0 = only voices, 1 = only the video, 0.5 = both at full volume.
  double balance = 0.5;
  bool autoPip = true;

  /// True while the mic button is held down with push to talk on.
  final talking = ValueNotifier<bool>(false);

  /// Volume (0–100) for other people's voices.
  int get voiceVolume => balance <= 0.5 ? 100 : ((1 - balance) * 200).round();

  /// Multiplier for the video's own volume slider.
  double get videoFactor => balance >= 0.5 ? 1 : balance * 2;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final p = await SharedPreferences.getInstance();
      pushToTalk = p.getBool(_kPtt) ?? false;
      balance = (p.getDouble(_kBalance) ?? 0.5).clamp(0.0, 1.0);
      autoPip = p.getBool(_kPip) ?? true;
      notifyListeners();
    } catch (_) {
      // Defaults are fine.
    }
  }

  Future<void> _save(void Function(SharedPreferences p) write) async {
    notifyListeners();
    try {
      write(await SharedPreferences.getInstance());
    } catch (_) {}
  }

  void setPushToTalk(bool v) {
    pushToTalk = v;
    _save((p) => p.setBool(_kPtt, v));
  }

  void setBalance(double v) {
    balance = v.clamp(0.0, 1.0);
    _save((p) => p.setDouble(_kBalance, balance));
  }

  void setAutoPip(bool v) {
    autoPip = v;
    _save((p) => p.setBool(_kPip, v));
  }
}
