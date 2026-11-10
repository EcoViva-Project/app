import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../local/places.dart';
import 'device_locator.dart';
import 'session_service.dart';

/// De onde veio a posição exata.
enum MyPositionSource {
  /// Localização do celular.
  gps,

  /// A pessoa marcou no mapa.
  manual,
}

/// Posição exata da própria pessoa, guardada só neste aparelho.
class MyPosition {
  const MyPosition({
    required this.lat,
    required this.lon,
    required this.source,
    required this.takenAt,
  });

  final double lat;
  final double lon;
  final MyPositionSource source;
  final DateTime takenAt;

  bool get isManual => source == MyPositionSource.manual;

  Map<String, dynamic> toJson() => {
    'lat': lat,
    'lon': lon,
    'source': source.name,
    'takenAt': takenAt.toIso8601String(),
  };

  static MyPosition? fromJson(Object? json) {
    if (json is! Map) return null;
    final lat = (json['lat'] as num?)?.toDouble();
    final lon = (json['lon'] as num?)?.toDouble();
    final takenAt = DateTime.tryParse('${json['takenAt']}');
    if (lat == null || lon == null || takenAt == null) return null;
    return MyPosition(
      lat: lat,
      lon: lon,
      source:
          json['source'] == MyPositionSource.manual.name
              ? MyPositionSource.manual
              : MyPositionSource.gps,
      takenAt: takenAt,
    );
  }
}

/// Como terminou uma tentativa de achar a localização.
enum LocateStatus {
  /// Achou a posição atual.
  ok,

  /// A pessoa não permitiu (dá para pedir de novo).
  permissionDenied,

  /// Permissão recusada de vez (só nas configurações do celular).
  deniedForever,

  /// A localização do celular está desligada.
  serviceOff,

  /// O celular não respondeu a tempo (comum em lugar fechado).
  timeout,

  /// A posição está fora do mapa de Rio Preto.
  outsideArea,

  /// Há uma posição marcada à mão; a atualização automática não mexe nela.
  keptManual,

  /// Qualquer outro problema (aparelho sem suporte, por exemplo).
  unavailable,
}

/// Resultado de [MyLocationService.locate].
class LocateResult {
  const LocateResult(this.status, {this.position, this.usedLastKnown = false});

  final LocateStatus status;

  /// Posição exata em uso depois da tentativa (pode ser uma anterior).
  final MyPosition? position;

  /// Não veio posição nova, mas a última posição do celular foi usada.
  final bool usedLastKnown;

  bool get ok => status == LocateStatus.ok || status == LocateStatus.keptManual;

  /// Uma frase simples para a pessoa, ou `null` se deu certo.
  ///
  /// [fallback] diz o que vale no lugar (por exemplo "seguimos com a região
  /// do seu bairro").
  String? message({required String fallback}) {
    switch (status) {
      case LocateStatus.ok:
      case LocateStatus.keptManual:
        return null;
      case LocateStatus.permissionDenied:
        return 'Você não permitiu a localização, então $fallback.';
      case LocateStatus.deniedForever:
        return 'A localização está bloqueada para o EcoViva nas configurações '
            'do celular, então $fallback.';
      case LocateStatus.serviceOff:
        return 'A localização do celular está desligada, então $fallback.';
      case LocateStatus.timeout:
        return usedLastKnown
            ? 'O celular demorou para achar sua localização; usamos a última '
                'posição que ele tinha.'
            : 'O celular não achou sua localização a tempo, então $fallback.';
      case LocateStatus.outsideArea:
        return 'Sua localização está fora do mapa de Rio Preto, então '
            '$fallback.';
      case LocateStatus.unavailable:
        return 'Não deu para usar a localização agora, então $fallback.';
    }
  }
}

/// Posição exata da pessoa que está usando o app.
///
/// Fica só neste aparelho (em `shared_preferences`, uma chave por usuário):
/// nunca vai para a API, nunca entra no banco do app e nunca aparece para
/// os outros. Os vizinhos continuam vendo só a região do bairro.
///
/// Nada aqui lança erro para a tela nem a deixa esperando: toda falha vira
/// um [LocateResult].
class MyLocationService extends ChangeNotifier {
  MyLocationService._();

  static final MyLocationService instance = MyLocationService._();

  /// Tempo máximo esperando o celular responder.
  static const Duration timeLimit = Duration(seconds: 10);

  static const String _positionPrefix = 'eco_my_position_';
  static const String _introPrefix = 'eco_my_location_intro_';

  /// Posição (e aviso) guardados por "Restaurar demonstração" para a próxima
  /// conta que entrar neste aparelho. Não começa com os prefixos acima.
  static const String _carryOverKey = 'eco_my_location_carry_over';

  DeviceLocator _locator = const GeolocatorDeviceLocator();

  SharedPreferences? _prefs;
  Object? _userId;
  MyPosition? _position;
  bool _introSeen = false;
  Future<LocateResult>? _locating;

  /// Muda a cada posição marcada ou apagada, para uma busca que termina
  /// depois não passar por cima.
  int _generation = 0;

  /// Troca o acesso à localização (os testes usam uma versão falsa).
  @visibleForTesting
  void useLocator(DeviceLocator locator) => _locator = locator;

  /// Esquece o que está em memória (os testes começam do zero).
  @visibleForTesting
  void debugReset() {
    _prefs = null;
    _userId = null;
    _position = null;
    _introSeen = false;
    _locating = null;
    _generation++;
  }

  static Object? get _currentUserId => SessionService.instance.user?['id'];

  /// Posição exata da pessoa logada, se houver.
  MyPosition? get position {
    final id = _currentUserId;
    return id != null && id == _userId ? _position : null;
  }

  bool get hasExactPosition => position != null;

  /// Uma busca de localização está em andamento.
  bool get locating => _locating != null;

  /// A explicação antes do pedido de permissão já apareceu para esta pessoa.
  bool get introSeen {
    final id = _currentUserId;
    return id != null && id == _userId && _introSeen;
  }

  Future<SharedPreferences> get _store async =>
      _prefs ??= await SharedPreferences.getInstance();

  /// Lê o que está guardado para a pessoa logada (uma vez por conta; depois
  /// vale o que está em memória, que é sempre gravado junto).
  ///
  /// Se "Restaurar demonstração" deixou uma posição guardada, a primeira
  /// conta que entra fica com ela (quando não tem posição própria) e a
  /// guarda é apagada: vale uma vez só.
  Future<void> load() async {
    final id = _currentUserId;
    if (id != null && id == _userId) return;
    MyPosition? position;
    var introSeen = false;
    if (id != null) {
      try {
        final prefs = await _store;
        final raw = prefs.getString('$_positionPrefix$id');
        if (raw != null) position = MyPosition.fromJson(jsonDecode(raw));
        introSeen = prefs.getBool('$_introPrefix$id') ?? false;
        final carried = prefs.getString(_carryOverKey);
        if (carried != null) {
          Object? data;
          try {
            data = jsonDecode(carried);
          } catch (_) {
            // Guarda estragada: só é apagada.
          }
          final writes = <Future<bool>>[];
          final carriedPosition =
              data is Map ? MyPosition.fromJson(data['position']) : null;
          if (position == null && carriedPosition != null) {
            position = carriedPosition;
            writes.add(
              prefs.setString(
                '$_positionPrefix$id',
                jsonEncode(position.toJson()),
              ),
            );
          }
          if (!introSeen && data is Map && data['introSeen'] == true) {
            introSeen = true;
            writes.add(prefs.setBool('$_introPrefix$id', true));
          }
          // Tudo trocado de uma vez, antes de esperar: outra leitura ao mesmo
          // tempo já encontra a posição na chave da conta.
          writes.add(prefs.remove(_carryOverKey));
          await Future.wait(writes);
        }
      } catch (_) {
        // Sem acesso ao armazenamento: fica a região do bairro.
      }
    }
    if (id != _currentUserId) return; // trocou de conta no meio
    final changed =
        id != _userId ||
        position?.lat != _position?.lat ||
        position?.lon != _position?.lon ||
        position?.source != _position?.source;
    _userId = id;
    _position = position;
    _introSeen = introSeen;
    if (changed) notifyListeners();
  }

  Future<void> _save(Object id, MyPosition? position) async {
    try {
      final prefs = await _store;
      if (position == null) {
        await prefs.remove('$_positionPrefix$id');
      } else {
        await prefs.setString(
          '$_positionPrefix$id',
          jsonEncode(position.toJson()),
        );
      }
    } catch (_) {
      // Continua valendo em memória até o app fechar.
    }
  }

  void _set(MyPosition? position) {
    final id = _currentUserId;
    if (id == null) return;
    if (id != _userId) _introSeen = false;
    _userId = id;
    _position = position;
    notifyListeners();
    unawaited(_save(id, position));
  }

  /// Marca que a explicação já apareceu (não mostra de novo).
  Future<void> markIntroSeen() async {
    final id = _currentUserId;
    if (id == null) return;
    await load();
    if (id != _userId) return;
    _introSeen = true;
    try {
      await (await _store).setBool('$_introPrefix$id', true);
    } catch (_) {}
  }

  /// Situação da permissão, sem perguntar nada.
  Future<LocatorPermission> permission() async {
    try {
      return await _locator.checkPermission();
    } catch (_) {
      return LocatorPermission.unknown;
    }
  }

  /// Posição marcada pela pessoa no mapa. Devolve `false` se o ponto está
  /// fora do mapa de Rio Preto.
  bool setManual(double lat, double lon) {
    if (!Places.insideMapArea(lat, lon)) return false;
    _generation++;
    _set(
      MyPosition(
        lat: lat,
        lon: lon,
        source: MyPositionSource.manual,
        takenAt: DateTime.now(),
      ),
    );
    return true;
  }

  /// Volta para a região do bairro.
  void clear() {
    _generation++;
    _set(null);
  }

  /// "Restaurar demonstração": apaga a posição e o aviso de todas as contas
  /// deste aparelho, menos os da pessoa logada, que ficam guardados para a
  /// próxima conta que entrar (na prática, a demonstração recriada).
  ///
  /// Na feira, a posição marcada à mão no salão sem GPS continua valendo
  /// entre uma apresentação e outra, com a mesma origem e o mesmo horário.
  Future<void> clearAllKeepingMine() async {
    final id = _currentUserId;
    MyPosition? mine;
    var introSeen = false;
    if (id != null && id == _userId) {
      mine = _position;
      introSeen = _introSeen;
    }
    _generation++;
    _userId = null; // a próxima [load] lê de novo (e adota a posição guardada)
    _position = null;
    _introSeen = false;
    try {
      final prefs = await _store;
      if (id != null && mine == null && !introSeen) {
        // Ainda não lida nesta execução do app: vem do armazenamento.
        final raw = prefs.getString('$_positionPrefix$id');
        if (raw != null) mine = MyPosition.fromJson(jsonDecode(raw));
        introSeen = prefs.getBool('$_introPrefix$id') ?? false;
      }
      for (final key in prefs.getKeys().toList()) {
        if (key.startsWith(_positionPrefix) || key.startsWith(_introPrefix)) {
          await prefs.remove(key);
        }
      }
      if (mine != null || introSeen) {
        await prefs.setString(
          _carryOverKey,
          jsonEncode({'position': mine?.toJson(), 'introSeen': introSeen}),
        );
      }
    } catch (_) {}
    notifyListeners();
  }

  /// Procura a localização do celular.
  ///
  /// Pergunta a permissão só se [askPermission] (nunca em segundo plano). Com
  /// [automatic], uma posição marcada à mão é mantida. A última posição
  /// conhecida do celular é usada na hora; depois vem a atual, com limite de
  /// [timeLimit]. Chamadas ao mesmo tempo dividem a mesma busca.
  Future<LocateResult> locate({
    bool automatic = false,
    bool askPermission = true,
  }) {
    final current = position;
    if (automatic && current != null && current.isManual) {
      return Future.value(
        LocateResult(LocateStatus.keptManual, position: current),
      );
    }
    final running = _locating;
    if (running != null) return running;
    final future = _locate(askPermission: askPermission);
    _locating = future;
    notifyListeners();
    return future.whenComplete(() {
      if (identical(_locating, future)) {
        _locating = null;
        notifyListeners();
      }
    });
  }

  Future<LocateResult> _locate({required bool askPermission}) async {
    final generation = _generation;
    final userId = _currentUserId;
    var usedLastKnown = false;

    // Uma posição marcada ou apagada durante a busca (ou outra conta) ganha.
    bool stillValid() => generation == _generation && userId == _currentUserId;

    LocateResult done(LocateStatus status) =>
        LocateResult(status, position: position, usedLastKnown: usedLastKnown);

    void accept(DevicePosition fix) {
      if (!stillValid()) return;
      _set(
        MyPosition(
          lat: fix.lat,
          lon: fix.lon,
          source: MyPositionSource.gps,
          takenAt: DateTime.now(),
        ),
      );
    }

    try {
      if (!await _locator.isServiceEnabled()) {
        return done(LocateStatus.serviceOff);
      }
      var permission = await _locator.checkPermission();
      if (permission == LocatorPermission.denied && askPermission) {
        permission = await _locator.requestPermission();
      }
      switch (permission) {
        case LocatorPermission.granted:
          break;
        case LocatorPermission.deniedForever:
          return done(LocateStatus.deniedForever);
        case LocatorPermission.denied:
          return done(LocateStatus.permissionDenied);
        case LocatorPermission.unknown:
          return done(LocateStatus.unavailable);
      }

      try {
        final last = await _locator.lastKnownPosition();
        if (last != null && Places.insideMapArea(last.lat, last.lon)) {
          accept(last);
          usedLastKnown = true;
        }
      } catch (_) {
        // Sem última posição: segue para a atual.
      }

      final DevicePosition fix;
      try {
        fix = await _locator
            .currentPosition(timeLimit: timeLimit)
            // Garantia caso o aparelho ignore o limite.
            .timeout(timeLimit + const Duration(seconds: 2));
      } on TimeoutException {
        return done(LocateStatus.timeout);
      }
      if (!Places.insideMapArea(fix.lat, fix.lon)) {
        return done(LocateStatus.outsideArea);
      }
      accept(fix);
      usedLastKnown = false;
      return done(LocateStatus.ok);
    } catch (_) {
      return done(LocateStatus.unavailable);
    }
  }
}
