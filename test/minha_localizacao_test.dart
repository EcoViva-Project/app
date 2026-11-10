import 'package:eco_app/core/local/places.dart';
import 'package:eco_app/core/services/auth_service.dart';
import 'package:eco_app/core/services/device_locator.dart';
import 'package:eco_app/core/services/my_location_service.dart';
import 'package:eco_app/core/services/neighborhood_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import 'support/fake_locator.dart';
import 'support/local_app.dart';

MyLocationService get _service => MyLocationService.instance;

FakeDeviceLocator _use(FakeDeviceLocator fake) {
  _service.useLocator(fake);
  return fake;
}

void main() {
  setUp(() async {
    await useLocalBackend();
    await signInDemo();
  });

  group('MyLocationService', () {
    test(
      'com permissão: usa a posição do celular, sem perguntar nada',
      () async {
        final fake = _use(FakeDeviceLocator(current: posicaoNoCentro));
        final result = await _service.locate();

        expect(result.status, LocateStatus.ok);
        expect(result.message(fallback: 'x'), isNull);
        expect(_service.position?.lat, posicaoNoCentro.lat);
        expect(_service.position?.lon, posicaoNoCentro.lon);
        expect(_service.position?.source, MyPositionSource.gps);
        expect(fake.permissionRequests, 0);
        expect(_service.locating, isFalse);
      },
    );

    test(
      'permissão negada: pergunta uma vez e fica sem posição exata',
      () async {
        final fake = _use(
          FakeDeviceLocator(
            permission: LocatorPermission.denied,
            current: posicaoNoCentro,
          ),
        );
        final result = await _service.locate();

        expect(result.status, LocateStatus.permissionDenied);
        expect(fake.permissionRequests, 1);
        expect(fake.currentCalls, 0);
        expect(_service.position, isNull);
        expect(
          result.message(fallback: 'seguimos com a região do seu bairro'),
          'Você não permitiu a localização, então seguimos com a região do seu '
          'bairro.',
        );
      },
    );

    test('permissão concedida no pedido: segue e acha a posição', () async {
      final fake = _use(
        FakeDeviceLocator(
          permission: LocatorPermission.denied,
          permissionAfterRequest: LocatorPermission.granted,
          current: posicaoNoCentro,
        ),
      );
      final result = await _service.locate();
      expect(result.status, LocateStatus.ok);
      expect(fake.permissionRequests, 1);
      expect(_service.hasExactPosition, isTrue);
    });

    test('atualização automática não pergunta a permissão', () async {
      final fake = _use(
        FakeDeviceLocator(
          permission: LocatorPermission.denied,
          current: posicaoNoCentro,
        ),
      );
      final result = await _service.locate(
        automatic: true,
        askPermission: false,
      );
      expect(result.status, LocateStatus.permissionDenied);
      expect(fake.permissionRequests, 0);
    });

    test('permissão negada de vez: não pergunta de novo', () async {
      final fake = _use(
        FakeDeviceLocator(
          permission: LocatorPermission.deniedForever,
          current: posicaoNoCentro,
        ),
      );
      final result = await _service.locate();
      expect(result.status, LocateStatus.deniedForever);
      expect(fake.permissionRequests, 0);
      expect(_service.position, isNull);
      expect(result.message(fallback: 'f'), contains('configurações'));
    });

    test('localização do celular desligada', () async {
      final fake = _use(
        FakeDeviceLocator(serviceEnabled: false, current: posicaoNoCentro),
      );
      final result = await _service.locate();
      expect(result.status, LocateStatus.serviceOff);
      expect(fake.currentCalls, 0);
      expect(_service.position, isNull);
      expect(result.message(fallback: 'f'), contains('desligada'));
    });

    test('tempo esgotado sem última posição: fica sem posição exata', () async {
      _use(FakeDeviceLocator(timesOut: true));
      final result = await _service.locate();
      expect(result.status, LocateStatus.timeout);
      expect(result.usedLastKnown, isFalse);
      expect(_service.position, isNull);
      expect(
        result.message(fallback: 'seguimos com a região do seu bairro'),
        'O celular não achou sua localização a tempo, então seguimos com a '
        'região do seu bairro.',
      );
    });

    test('tempo esgotado com última posição: usa a última posição', () async {
      _use(FakeDeviceLocator(timesOut: true, lastKnown: posicaoNoNorte));
      final result = await _service.locate();
      expect(result.status, LocateStatus.timeout);
      expect(result.usedLastKnown, isTrue);
      expect(_service.position?.lat, posicaoNoNorte.lat);
      expect(result.message(fallback: 'f'), contains('última posição'));
    });

    test('a última posição aparece na hora; a atual a substitui', () async {
      final fake = _use(
        FakeDeviceLocator(lastKnown: posicaoNoNorte, current: posicaoNoCentro)
          ..gate = Completer<void>(),
      );
      final running = _service.locate();
      await pumpEventQueue();
      expect(_service.locating, isTrue);
      expect(_service.position?.lat, posicaoNoNorte.lat);
      fake.gate!.complete();
      final result = await running;
      expect(result.status, LocateStatus.ok);
      expect(result.usedLastKnown, isFalse);
      expect(_service.position?.lat, posicaoNoCentro.lat);
      expect(_service.locating, isFalse);
    });

    test('posição fora do mapa de Rio Preto é recusada', () async {
      _use(
        FakeDeviceLocator(
          lastKnown: posicaoForaDoMapa,
          current: posicaoForaDoMapa,
        ),
      );
      final result = await _service.locate();
      expect(result.status, LocateStatus.outsideArea);
      expect(_service.position, isNull);
      expect(result.message(fallback: 'f'), contains('fora do mapa'));
    });

    test('erro do aparelho vira resultado, nunca exceção', () async {
      _use(FakeDeviceLocator(fails: true));
      final result = await _service.locate();
      expect(result.status, LocateStatus.unavailable);
      expect(await _service.permission(), LocatorPermission.unknown);
      expect(_service.locating, isFalse);
    });

    test(
      'posição marcada à mão não é trocada pela atualização automática',
      () async {
        final fake = _use(FakeDeviceLocator(current: posicaoNoCentro));
        expect(
          _service.setManual(posicaoNoNorte.lat, posicaoNoNorte.lon),
          isTrue,
        );

        final automatic = await _service.locate(automatic: true);
        expect(automatic.status, LocateStatus.keptManual);
        expect(fake.currentCalls, 0);
        expect(_service.position?.source, MyPositionSource.manual);
        expect(_service.position?.lat, posicaoNoNorte.lat);

        // "Usar minha localização" troca.
        final explicit = await _service.locate();
        expect(explicit.status, LocateStatus.ok);
        expect(_service.position?.source, MyPositionSource.gps);
        expect(_service.position?.lat, posicaoNoCentro.lat);
      },
    );

    test('marcar à mão durante a busca ganha da resposta do celular', () async {
      final fake = _use(FakeDeviceLocator(current: posicaoNoCentro))
        ..gate = Completer<void>();
      final running = _service.locate();
      await pumpEventQueue();
      _service.setManual(posicaoNoNorte.lat, posicaoNoNorte.lon);
      fake.gate!.complete();
      await running;
      expect(_service.position?.source, MyPositionSource.manual);
      expect(_service.position?.lat, posicaoNoNorte.lat);
    });

    test('marcar fora do mapa não vale; voltar para o bairro apaga', () async {
      expect(
        _service.setManual(posicaoForaDoMapa.lat, posicaoForaDoMapa.lon),
        isFalse,
      );
      expect(_service.position, isNull);
      _service.setManual(posicaoNoNorte.lat, posicaoNoNorte.lon);
      expect(_service.hasExactPosition, isTrue);
      _service.clear();
      expect(_service.position, isNull);
    });

    test('fica guardada por usuário, só no aparelho', () async {
      _service.setManual(posicaoNoNorte.lat, posicaoNoNorte.lon);
      await pumpEventQueue();

      // Lida de novo do armazenamento.
      _service.debugReset();
      expect(_service.position, isNull);
      await _service.load();
      expect(_service.position?.lat, posicaoNoNorte.lat);
      expect(_service.position?.source, MyPositionSource.manual);

      // Outra pessoa no mesmo aparelho não vê a posição da Clara.
      await AuthService.instance.logout();
      expect(_service.position, isNull);
      await AuthService.instance.register(
        name: 'Bruno Lima',
        email: 'bruno@eco.app',
        password: 'segredo123',
        neighborhood: 'Vila Toninho',
      );
      await _service.load();
      expect(_service.position, isNull);
      _service.setManual(posicaoNoCentro.lat, posicaoNoCentro.lon);
      await pumpEventQueue();

      await AuthService.instance.logout();
      await signInDemo();
      await _service.load();
      expect(_service.position?.lat, posicaoNoNorte.lat);

      // Nada disso foi para a API: o usuário continua na região do bairro.
      final location = AuthService.instance.location!;
      expect(location.lat, isNot(posicaoNoNorte.lat));
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith('eco_my_'));
      expect(keys, hasLength(2));
    });

    test('"Restaurar demonstração" apaga a posição de todos', () async {
      _service.setManual(posicaoNoNorte.lat, posicaoNoNorte.lon);
      await _service.markIntroSeen();
      await pumpEventQueue();

      await AuthService.instance.resetDemo();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys().where((k) => k.startsWith('eco_my_')), isEmpty);

      await signInDemo();
      await _service.load();
      expect(_service.position, isNull);
      expect(_service.introSeen, isFalse);
    });
  });

  group('distâncias até os pontos de coleta', () {
    test('com posição exata, recalcula e reordena do mais perto', () async {
      final service = NeighborhoodService.instance;
      final before = service.collectionPoints;
      expect(before, isNotEmpty);
      expect(service.distancesFromMyPosition, isFalse);

      _service.setManual(posicaoNoNorte.lat, posicaoNoNorte.lon);
      final after = service.collectionPoints;
      expect(service.distancesFromMyPosition, isTrue);
      expect(after, hasLength(before.length));
      for (final point in after.where((p) => p.hasPosition)) {
        expect(
          point.distanceMeters,
          Places.distanceMeters(
            posicaoNoNorte.lat,
            posicaoNoNorte.lon,
            point.lat!,
            point.lon!,
          ),
        );
      }
      final distances = [
        for (final point in after)
          if (point.distanceMeters != null) point.distanceMeters!,
      ];
      expect(distances, orderedEquals([...distances]..sort()));
      // A ordem mudou: o mais perto da zona norte não é o mais perto do
      // bairro da Clara.
      expect(after.first.id, isNot(before.first.id));

      // Voltar para a região do bairro devolve as distâncias da API.
      _service.clear();
      expect(
        [for (final p in service.collectionPoints) p.distanceMeters],
        [for (final p in before) p.distanceMeters],
      );
    });
  });
}
