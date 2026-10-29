import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import 'api_client.dart';
import 'api_exception.dart';
import 'google_auth_service.dart';

enum AuthStatus { loading, authed, anon }

/// Mirrors the web app's src/auth/AuthContext.jsx — same token-persistence
/// and status-machine shape, wired to the same backend.
class AuthProvider extends ChangeNotifier {
  static const _tokenKey = 'flingToken';
  // Last profile we got from the server, so the app opens signed in even
  // while the server is still waking up or the phone is offline.
  static const _profileKey = 'flingProfile';
  Timer? _retry;

  String? _token;
  User? _user;
  AuthStatus _status = AuthStatus.loading;

  String? get token => _token;
  User? get user => _user;
  AuthStatus get status => _status;
  bool get isAuthed => _status == AuthStatus.authed;

  AuthProvider() {
    ApiClient.tokenGetter = () => _token;
    ApiClient.onUnauthorized = clearSession;
  }

  Future<void> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    if (_token == null || _token!.isEmpty) {
      _status = AuthStatus.anon;
      notifyListeners();
      return;
    }
    // Only a 401 means the saved login is really over. Anything else (the
    // server waking up, no signal, a rate limit) keeps you signed in.
    if (await _tryMe()) return;
    final cached = prefs.getString(_profileKey);
    if (cached != null) {
      try {
        _user = User.fromJson(jsonDecode(cached) as Map<String, dynamic>);
        _status = AuthStatus.authed;
        notifyListeners();
        _keepRetrying();
        return;
      } catch (_) {}
    }
    // No saved profile yet: give a sleeping server time to wake up.
    for (final wait in const [3, 6, 10, 15, 20]) {
      if (_token == null) return; // a 401 cleared it
      await Future.delayed(Duration(seconds: wait));
      if (await _tryMe()) return;
    }
    if (_token == null) return;
    _status = AuthStatus.anon;
    notifyListeners();
  }

  /// GET /auth/me; true when signed in. A 401 signs out.
  Future<bool> _tryMe() async {
    try {
      final data = await ApiClient.get('/auth/me');
      await _applyMe(data as Map<String, dynamic>);
      _status = AuthStatus.authed;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      if (e.status == 401) await clearSession();
      return false;
    } catch (_) {
      return false;
    }
  }

  void _keepRetrying() {
    _retry?.cancel();
    var tries = 0;
    _retry = Timer.periodic(const Duration(seconds: 15), (t) async {
      if (_token == null || ++tries > 40) return t.cancel();
      if (await _tryMe()) t.cancel();
    });
  }

  /// Saves the profile (and a renewed token, when the server sends one).
  Future<void> _applyMe(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final renewed = data['token'];
    if (renewed is String && renewed.isNotEmpty) {
      _token = renewed;
      await prefs.setString(_tokenKey, renewed);
    }
    final profile = Map<String, dynamic>.from(data)..remove('token');
    _user = User.fromJson(profile);
    await prefs.setString(_profileKey, jsonEncode(profile));
  }

  Future<void> _persistToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  /// TEST-ONLY dev-login path (mirrors POST /auth/dev-login on the backend —
  /// only works for whitelisted phone numbers, disabled in production).
  Future<void> devLogin(String phone) async {
    final data = await ApiClient.post('/auth/dev-login',
        body: {'phone': phone}, skipAuth: true);
    final map = data as Map<String, dynamic>;
    _token = map['token'] as String;
    await _persistToken(_token!);
    await _applyMe(map['user'] as Map<String, dynamic>);
    _status = AuthStatus.authed;
    notifyListeners();
  }

  /// Admin-created fake/bot accounts (see POST /admin/fake-users) log in
  /// with a username+password instead of phone OTP.
  Future<void> loginFake(String username, String password) async {
    final data = await ApiClient.post('/auth/login-fake',
        body: {'username': username, 'password': password}, skipAuth: true);
    final map = data as Map<String, dynamic>;
    _token = map['token'] as String;
    await _persistToken(_token!);
    await _applyMe(map['user'] as Map<String, dynamic>);
    _status = AuthStatus.authed;
    notifyListeners();
  }

  Future<void> loginWithFirebaseIdToken(String idToken) async {
    final data = await ApiClient.post('/auth/firebase',
        body: {'idToken': idToken}, skipAuth: true);
    final map = data as Map<String, dynamic>;
    _token = map['token'] as String;
    await _persistToken(_token!);
    await _applyMe(map['user'] as Map<String, dynamic>);
    _status = AuthStatus.authed;
    notifyListeners();
  }

  Future<void> refreshUser() async {
    if (!isAuthed) return;
    try {
      final data = await ApiClient.get('/auth/me');
      await _applyMe(data as Map<String, dynamic>);
      notifyListeners();
    } on ApiException {
      // onUnauthorized already handles 401; ignore transient failures here.
    }
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_profileKey);
    _retry?.cancel();
    // Also leave Google/Firebase, so the next sign-in can pick another
    // account. Best-effort: Firebase may not be set up (tests, web).
    try {
      await GoogleAuthService.signOut();
    } catch (_) {}
    _token = null;
    _user = null;
    _status = AuthStatus.anon;
    notifyListeners();
  }
}
