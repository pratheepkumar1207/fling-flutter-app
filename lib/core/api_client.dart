import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_exception.dart';

/// Thin REST wrapper mirroring the web app's src/api/client.js — same base
/// URL, same auth-header injection, same 401 -> unauthorizedHandler flow, so
/// the two clients behave identically against the shared backend.
class ApiClient {
  ApiClient._();

  /// Same deployed backend the web app talks to.
  static const String baseUrl = 'https://fling-production.up.railway.app';

  static String? Function()? tokenGetter;
  static void Function()? onUnauthorized;

  static Future<dynamic> get(String path, {bool skipAuth = false}) =>
      _request(path, method: 'GET', skipAuth: skipAuth);

  static Future<dynamic> post(String path, {dynamic body, bool skipAuth = false}) =>
      _request(path, method: 'POST', body: body, skipAuth: skipAuth);

  static Future<dynamic> patch(String path, {dynamic body, bool skipAuth = false}) =>
      _request(path, method: 'PATCH', body: body, skipAuth: skipAuth);

  static Future<dynamic> delete(String path, {dynamic body, bool skipAuth = false}) =>
      _request(path, method: 'DELETE', body: body, skipAuth: skipAuth);

  static Future<dynamic> _request(
    String path, {
    required String method,
    dynamic body,
    bool skipAuth = false,
  }) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (!skipAuth) {
      final token = tokenGetter?.call();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    final uri = Uri.parse('$baseUrl$path');
    late final http.Response res;
    final encodedBody = body != null ? jsonEncode(body) : null;

    switch (method) {
      case 'POST':
        res = await http.post(uri, headers: headers, body: encodedBody);
        break;
      case 'PATCH':
        res = await http.patch(uri, headers: headers, body: encodedBody);
        break;
      case 'DELETE':
        res = await http.delete(uri, headers: headers, body: encodedBody);
        break;
      case 'GET':
      default:
        res = await http.get(uri, headers: headers);
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
      throw ApiException(data is Map ? (data['error'] ?? 'Session expired') : 'Session expired', status: 401);
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      final message = data is Map ? (data['error'] ?? 'Request failed') : 'Request failed';
      throw ApiException(message, status: res.statusCode, data: data);
    }

    return data;
  }
}
