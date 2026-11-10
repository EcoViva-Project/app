import 'dart:async';

import 'package:eco_app/core/services/device_locator.dart';

/// Posição dentro do mapa de Rio Preto (perto do Centro).
const DevicePosition posicaoNoCentro = (lat: -20.8123, lon: -49.3801);

/// Outra posição dentro do mapa (zona norte).
const DevicePosition posicaoNoNorte = (lat: -20.7600, lon: -49.3500);

/// Posição fora do mapa (São Paulo).
const DevicePosition posicaoForaDoMapa = (lat: -23.5505, lon: -46.6333);

/// Localização de mentira para os testes: nada passa pelo sistema.
class FakeDeviceLocator implements DeviceLocator {
  FakeDeviceLocator({
    this.serviceEnabled = true,
    this.permission = LocatorPermission.granted,
    this.permissionAfterRequest,
    this.lastKnown,
    this.current,
    this.timesOut = false,
    this.fails = false,
  });

  bool serviceEnabled;
  LocatorPermission permission;

  /// Resposta ao pedido de permissão (por padrão, a mesma de [permission]).
  LocatorPermission? permissionAfterRequest;
  DevicePosition? lastKnown;
  DevicePosition? current;

  /// [currentPosition] estoura o tempo.
  bool timesOut;

  /// Toda chamada lança erro (aparelho sem suporte).
  bool fails;

  /// Se definido, [currentPosition] espera ele completar.
  Completer<void>? gate;

  int permissionRequests = 0;
  int currentCalls = 0;

  void _check() {
    if (fails) throw StateError('sem localização neste aparelho');
  }

  @override
  Future<bool> isServiceEnabled() async {
    _check();
    return serviceEnabled;
  }

  @override
  Future<LocatorPermission> checkPermission() async {
    _check();
    return permission;
  }

  @override
  Future<LocatorPermission> requestPermission() async {
    _check();
    permissionRequests++;
    permission = permissionAfterRequest ?? permission;
    return permission;
  }

  @override
  Future<DevicePosition?> lastKnownPosition() async {
    _check();
    return lastKnown;
  }

  @override
  Future<DevicePosition> currentPosition({required Duration timeLimit}) async {
    _check();
    currentCalls++;
    final wait = gate;
    if (wait != null) await wait.future;
    if (timesOut || current == null) {
      throw TimeoutException('sem resposta', timeLimit);
    }
    return current!;
  }
}
