import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform, SocketException;
import 'package:http/http.dart' as http;
import 'api_exception.dart';

/// Thin REST wrapper mirroring the web app's src/api/client.js — same base
/// URL, same auth-header injection, same 401 -> unauthorizedHandler flow, so
/// the two clients behave identically against the shared backend.
class ApiClient {
  ApiClient._();

  /// Shown on Settings → Security's list of signed-in devices.
  static String get deviceName {
    try {
      if (Platform.isAndroid) return 'Android phone';
      if (Platform.isIOS) return 'iPhone';
      return Platform.operatingSystem;
    } catch (_) {
      return 'Web';
    }
  }

  /// Same deployed backend the web app talks to. Moved from Railway to
  /// Render (Singapore) in 2026-10 — see the backend's render.yaml. Local
  /// builds override it with --dart-define=API_BASE_URL=http://localhost:4000.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://fling-backend.onrender.com',
  );

  static String? Function()? tokenGetter;
  static void Function()? onUnauthorized;

  static Duration getTimeout = const Duration(seconds: 30);
  static Duration sendTimeout = const Duration(seconds: 120);

  static Future<dynamic> get(String path, {bool skipAuth = false}) =>
      _request(path, method: 'GET', skipAuth: skipAuth);

  static Future<dynamic> post(String path,
          {dynamic body, bool skipAuth = false}) =>
      _request(path, method: 'POST', body: body, skipAuth: skipAuth);

  static Future<dynamic> patch(String path,
          {dynamic body, bool skipAuth = false}) =>
      _request(path, method: 'PATCH', body: body, skipAuth: skipAuth);

  static Future<dynamic> put(String path,
          {dynamic body, bool skipAuth = false}) =>
      _request(path, method: 'PUT', body: body, skipAuth: skipAuth);

  static Future<dynamic> delete(String path,
          {dynamic body, bool skipAuth = false}) =>
      _request(path, method: 'DELETE', body: body, skipAuth: skipAuth);

  static Future<dynamic> _request(
    String path, {
    required String method,
    dynamic body,
    bool skipAuth = false,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'X-Device-Name': deviceName,
    };
    if (!skipAuth) {
      final token = tokenGetter?.call();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    final uri = Uri.parse('$baseUrl$path');
    late final http.Response res;
    final encodedBody = body != null ? jsonEncode(body) : null;

    // Uploads carry photos and voice notes, so they get longer.
    final limit = method == 'GET' ? getTimeout : sendTimeout;
    try {
      final Future<http.Response> sent = switch (method) {
        'POST' => http.post(uri, headers: headers, body: encodedBody),
        'PATCH' => http.patch(uri, headers: headers, body: encodedBody),
        'PUT' => http.put(uri, headers: headers, body: encodedBody),
        'DELETE' => http.delete(uri, headers: headers, body: encodedBody),
        _ => http.get(uri, headers: headers),
      };
      res = await sent.timeout(limit);
    } on TimeoutException {
      throw ApiException(
          'This is taking too long. Check your connection and try again.',
          status: 0);
    } on SocketException {
      throw ApiException('No internet connection.', status: 0);
    } on http.ClientException {
      throw ApiException('No internet connection.', status: 0);
    }

    dynamic data;
    if (res.body.isNotEmpty) {
      try {
        data = jsonDecode(res.body);
      } catch (_) {
        data = null;
      }
    }

    if (res.statusCode == 401 && !skipAuth) {
      onUnauthorized?.call();
      throw ApiException(
          data is Map
              ? (data['error'] ?? 'Session expired')
              : 'Session expired',
          status: 401);
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      final message =
          data is Map ? (data['error'] ?? 'Request failed') : 'Request failed';
      throw ApiException(message, status: res.statusCode, data: data);
    }

    return data;
  }
}
