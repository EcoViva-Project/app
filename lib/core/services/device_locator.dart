import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';

/// Situação da permissão de localização do app.
enum LocatorPermission {
  /// Permitida enquanto o app está aberto (ou sempre).
  granted,

  /// Ainda não pedida, ou recusada uma vez: dá para pedir de novo.
  denied,

  /// Recusada de vez: só nas configurações do celular.
  deniedForever,

  /// Não deu para saber (plataforma sem suporte, por exemplo).
  unknown,
}

/// Uma leitura de posição do aparelho.
typedef DevicePosition = ({double lat, double lon});

/// Acesso à localização do aparelho.
///
/// Todas as chamadas ao plugin ficam aqui, atrás desta interface, para os
/// testes usarem uma versão falsa sem tocar no sistema.
abstract class DeviceLocator {
  /// A localização do celular está ligada.
  Future<bool> isServiceEnabled();

  /// Situação atual da permissão, sem perguntar nada à pessoa.
  Future<LocatorPermission> checkPermission();

  /// Mostra o pedido do sistema (só "enquanto o app estiver em uso").
  Future<LocatorPermission> requestPermission();

  /// Última posição guardada pelo celular, se houver (resposta imediata).
  Future<DevicePosition?> lastKnownPosition();

  /// Posição atual. Lança [TimeoutException] se passar de [timeLimit].
  Future<DevicePosition> currentPosition({required Duration timeLimit});
}

/// [DeviceLocator] de verdade, pelo plugin `geolocator`.
class GeolocatorDeviceLocator implements DeviceLocator {
  const GeolocatorDeviceLocator();

  static LocatorPermission _map(LocationPermission permission) =>
      switch (permission) {
        LocationPermission.always ||
        LocationPermission.whileInUse => LocatorPermission.granted,
        LocationPermission.denied => LocatorPermission.denied,
        LocationPermission.deniedForever => LocatorPermission.deniedForever,
        LocationPermission.unableToDetermine => LocatorPermission.unknown,
      };

  @override
  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  @override
  Future<LocatorPermission> checkPermission() async =>
      _map(await Geolocator.checkPermission());

  @override
  Future<LocatorPermission> requestPermission() async =>
      _map(await Geolocator.requestPermission());

  @override
  Future<DevicePosition?> lastKnownPosition() async {
    // O navegador não guarda a última posição.
    if (kIsWeb) return null;
    final position = await Geolocator.getLastKnownPosition();
    return position == null
        ? null
        : (lat: position.latitude, lon: position.longitude);
  }

  @override
  Future<DevicePosition> currentPosition({required Duration timeLimit}) async {
    final position = await Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: timeLimit,
      ),
    );
    return (lat: position.latitude, lon: position.longitude);
  }
}
