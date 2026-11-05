import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Cliente HTTP único da aplicação.
///
/// A URL pode ser trocada em tempo de build:
/// `flutter run --dart-define=ECO_API_URL=http://10.0.2.2:3000/api`
class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  static const String baseUrl = String.fromEnvironment(
    'ECO_API_URL',
    defaultValue: 'http://127.0.0.1:3000/api',
  );

  String? _token;

  String? get token => _token;

  void setToken(String? token) {
    _token = token;
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null && _token!.isNotEmpty) 'Authorization': 'Bearer $_token',
  };

  Uri _uri(String path, [Map<String, String>? query]) {
    final normalized = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$normalized').replace(queryParameters: query);
  }

  Future<dynamic> get(String path, {Map<String, String>? query}) async {
    return _send(() => http.get(_uri(path, query), headers: _headers));
  }

  Future<dynamic> post(String path, [Object? body]) async {
    return _send(
      () => http.post(
        _uri(path),
        headers: _headers,
        body: jsonEncode(body ?? const <String, dynamic>{}),
      ),
    );
  }

  Future<dynamic> patch(String path, [Object? body]) async {
    return _send(
      () => http.patch(
        _uri(path),
        headers: _headers,
        body: jsonEncode(body ?? const <String, dynamic>{}),
      ),
    );
  }

  Future<dynamic> delete(String path) async {
    return _send(() => http.delete(_uri(path), headers: _headers));
  }

  Future<dynamic> _send(Future<http.Response> Function() request) async {
    http.Response response;
    try {
      response = await request();
    } catch (_) {
      throw ApiException(
        'Não foi possível conectar ao servidor. Verifique se a API está ativa.',
      );
    }

    final body = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    final message =
        body is Map && body['error'] != null
            ? body['error'].toString()
            : 'Erro inesperado (${response.statusCode}).';
    throw ApiException(message, statusCode: response.statusCode);
  }
}
