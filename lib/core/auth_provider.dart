import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import 'api_client.dart';
import 'api_exception.dart';

enum AuthStatus { loading, authed, anon }

/// Mirrors the web app's src/auth/AuthContext.jsx — same token-persistence
/// and status-machine shape, wired to the same backend.
class AuthProvider extends ChangeNotifier {
  static const _tokenKey = 'flingToken';

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
    try {
      final data = await ApiClient.get('/auth/me');
      _user = User.fromJson(data as Map<String, dynamic>);
      _status = AuthStatus.authed;
    } catch (_) {
      await clearSession();
      return;
    }
    notifyListeners();
  }

  Future<void> _persistToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  /// TEST-ONLY dev-login path (mirrors POST /auth/dev-login on the backend —
  /// only works for whitelisted phone numbers, disabled in production).
  Future<void> devLogin(String phone) async {
    final data = await ApiClient.post('/auth/dev-login', body: {'phone': phone}, skipAuth: true);
    final map = data as Map<String, dynamic>;
    _token = map['token'] as String;
    _user = User.fromJson(map['user'] as Map<String, dynamic>);
    _status = AuthStatus.authed;
    await _persistToken(_token!);
    notifyListeners();
  }

  /// Admin-created fake/bot accounts (see POST /admin/fake-users) log in
  /// with a username+password instead of phone OTP.
  Future<void> loginFake(String username, String password) async {
    final data = await ApiClient.post('/auth/login-fake', body: {'username': username, 'password': password}, skipAuth: true);
    final map = data as Map<String, dynamic>;
    _token = map['token'] as String;
    _user = User.fromJson(map['user'] as Map<String, dynamic>);
    _status = AuthStatus.authed;
    await _persistToken(_token!);
    notifyListeners();
  }

  Future<void> loginWithFirebaseIdToken(String idToken) async {
    final data = await ApiClient.post('/auth/firebase', body: {'idToken': idToken}, skipAuth: true);
    final map = data as Map<String, dynamic>;
    _token = map['token'] as String;
    _user = User.fromJson(map['user'] as Map<String, dynamic>);
    _status = AuthStatus.authed;
    await _persistToken(_token!);
    notifyListeners();
  }

  Future<void> refreshUser() async {
    if (!isAuthed) return;
    try {
      final data = await ApiClient.get('/auth/me');
      _user = User.fromJson(data as Map<String, dynamic>);
      notifyListeners();
    } on ApiException {
      // onUnauthorized already handles 401; ignore transient failures here.
    }
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    _token = null;
    _user = null;
    _status = AuthStatus.anon;
    notifyListeners();
  }
}
