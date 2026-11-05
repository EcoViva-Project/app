import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';

/// Persiste o token e o usuário autenticado entre execuções.
class SessionService {
  SessionService._();

  static final SessionService instance = SessionService._();

  static const String _tokenKey = 'eco_token';
  static const String _userKey = 'eco_user';

  SharedPreferences? _prefs;

  String? token;
  Map<String, dynamic>? user;

  bool get isAuthenticated => token != null && token!.isNotEmpty;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    token = _prefs!.getString(_tokenKey);
    final rawUser = _prefs!.getString(_userKey);
    if (rawUser != null) {
      try {
        user = jsonDecode(rawUser) as Map<String, dynamic>;
      } catch (_) {
        user = null;
      }
    }
    ApiClient.instance.setToken(token);
  }

  Future<void> save({
    required String token,
    required Map<String, dynamic> user,
  }) async {
    this.token = token;
    this.user = user;
    ApiClient.instance.setToken(token);
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(_tokenKey, token);
    await _prefs!.setString(_userKey, jsonEncode(user));
  }

  Future<void> updateUser(Map<String, dynamic> user) async {
    this.user = user;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(_userKey, jsonEncode(user));
  }

  Future<void> clear() async {
    token = null;
    user = null;
    ApiClient.instance.setToken(null);
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.remove(_tokenKey);
    await _prefs!.remove(_userKey);
  }
}
