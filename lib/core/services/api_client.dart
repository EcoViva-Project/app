import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../local/local_api.dart';
import '../local/local_store.dart';
import '../local/sqlite_store.dart';
import 'api_exception.dart';

export 'api_exception.dart';

/// Caminho por onde as requisições do app chegam às regras de negócio.
abstract class ApiTransport {
  Future<dynamic> send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    String? token,
  });
}

/// Fala com o `eco-backend` pela rede.
class HttpTransport implements ApiTransport {
  HttpTransport({
    required this.baseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 12),
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final Duration timeout;
  final http.Client _client;

  Uri _uri(String path, Map<String, String>? query) {
    final normalized = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$normalized').replace(queryParameters: query);
  }

  @override
  Future<dynamic> send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    String? token,
  }) async {
    final request = http.Request(method, _uri(path, query));
    request.headers['Accept'] = 'application/json';
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    if (method != 'GET' && method != 'DELETE') {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body ?? const <String, dynamic>{});
    }

    http.Response response;
    try {
      response = await http.Response.fromStream(
        await _client.send(request).timeout(timeout),
      );
    } on TimeoutException {
      throw ApiException(
        'O servidor demorou para responder. Tente de novo em instantes.',
      );
    } catch (_) {
      throw ApiException(
        'Não foi possível conectar. Verifique sua conexão e tente de novo.',
      );
    }

    dynamic decoded;
    if (response.body.isNotEmpty) {
      try {
        decoded = jsonDecode(utf8.decode(response.bodyBytes));
      } catch (_) {
        throw ApiException(
          'O servidor respondeu de um jeito inesperado (${response.statusCode}).',
          statusCode: response.statusCode,
        );
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }
    final message =
        decoded is Map && decoded['error'] != null
            ? decoded['error'].toString()
            : 'Erro inesperado (${response.statusCode}).';
    throw ApiException(message, statusCode: response.statusCode);
  }
}

/// Atende as requisições dentro do próprio app, com o banco do aparelho.
class LocalTransport implements ApiTransport {
  LocalTransport(this.api);

  final LocalApi api;

  @override
  Future<dynamic> send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    String? token,
  }) async {
    try {
      return await api.handle(
        method,
        path,
        query: query,
        body: body,
        token: token,
      );
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException(
        'Não foi possível acessar os dados deste aparelho. Feche e abra o aplicativo.',
        statusCode: 500,
      );
    }
  }
}

/// Usa o SQLite do aparelho e, se ele não estiver disponível (navegador,
/// testes ou falha inesperada), passa a gravar em `shared_preferences`.
class ResilientStore implements LocalStore {
  ResilientStore({LocalStore? primary, LocalStore? fallback})
    : _active = primary ?? SqliteStore(),
      _fallback = fallback ?? PrefsStore();

  LocalStore _active;
  final LocalStore _fallback;

  bool get usingFallback => identical(_active, _fallback);

  @override
  Future<Map<String, List<DbRow>>> load() async {
    try {
      return await _active.load();
    } catch (_) {
      _active = _fallback;
      return _active.load();
    }
  }

  @override
  Future<void> insert(String table, DbRow row) => _active.insert(table, row);

  @override
  Future<void> update(String table, int id, DbRow values) =>
      _active.update(table, id, values);

  @override
  Future<void> delete(String table, int id) => _active.delete(table, id);

  @override
  Future<void> replaceAll(Map<String, List<DbRow>> tables) =>
      _active.replaceAll(tables);
}

/// Cliente único da aplicação.
///
/// Dois modos, escolhidos na hora de gerar o app:
/// - `--dart-define=ECO_MODE=local` (padrão): tudo roda no aparelho, sem rede;
/// - `--dart-define=ECO_MODE=online --dart-define=ECO_API_URL=http://<host>:3100/api`:
///   usa o `eco-backend`.
class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  static const String mode = String.fromEnvironment(
    'ECO_MODE',
    defaultValue: 'local',
  );

  static const String baseUrl = String.fromEnvironment(
    'ECO_API_URL',
    defaultValue: 'http://127.0.0.1:3100/api',
  );

  static bool get isLocalMode => mode != 'online';

  ApiTransport? _transport;
  String? _token;

  /// Chamado quando a API recusa o token atual (sessão vencida ou inválida).
  VoidCallback? onUnauthorized;

  String? get token => _token;

  void setToken(String? token) {
    _token = token;
  }

  ApiTransport get transport => _transport ??= _defaultTransport();

  /// API local em uso, quando o app está no modo local.
  LocalApi? get localApi {
    final current = transport;
    return current is LocalTransport ? current.api : null;
  }

  /// Troca o transporte (usado nos testes).
  void useTransport(ApiTransport transport) {
    _transport = transport;
  }

  static ApiTransport _defaultTransport() {
    if (!isLocalMode) return HttpTransport(baseUrl: baseUrl);
    final LocalStore store = kIsWeb ? PrefsStore() : ResilientStore();
    return LocalTransport(LocalApi(LocalDatabase(store)));
  }

  Future<dynamic> get(String path, {Map<String, String>? query}) =>
      _send('GET', path, query: query);

  Future<dynamic> post(String path, [Object? body]) =>
      _send('POST', path, body: body);

  Future<dynamic> patch(String path, [Object? body]) =>
      _send('PATCH', path, body: body);

  Future<dynamic> delete(String path) => _send('DELETE', path);

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
  }) async {
    final sentToken = _token;
    try {
      return await transport.send(
        method,
        path,
        query: query,
        body: body,
        token: sentToken,
      );
    } on ApiException catch (error) {
      if (error.isUnauthorized && sentToken != null && sentToken.isNotEmpty) {
        onUnauthorized?.call();
      }
      rethrow;
    }
  }
}
