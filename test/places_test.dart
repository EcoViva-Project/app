import 'package:eco_app/core/local/data/neighborhoods_data.dart';
import 'package:eco_app/core/local/places.dart';
import 'package:eco_app/core/services/auth_service.dart';
import 'package:eco_app/core/services/neighborhood_service.dart';
import 'package:eco_app/features/auth/presentation/widgets/address_fields.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/local_app.dart';

String? _name(String text) => Places.findNeighborhood(text)?.name;

void main() {
  group('Places.findNeighborhood', () {
    test('todo bairro da lista acha a si mesmo', () {
      for (final item in neighborhoodsData) {
        expect(Places.findNeighborhood(item.name), item, reason: item.name);
      }
    });

    test('aceita abreviações, pontuação e "de/da/do"', () {
      expect(_name('Jd. Nazareth'), 'Jardim Nazareth');
      expect(_name('jd nazareth'), 'Jardim Nazareth');
      expect(_name('Vl Ercilia'), 'Vila Ercília');
      expect(_name('Pq Industrial'), 'Parque Industrial');
      expect(_name('Res. Lago Sul'), 'Residencial Lago Sul');
      expect(_name('Cj Hab Cristo Rei'), 'Conjunto Habitacional Cristo Rei');
      expect(_name('Vila Sto Antonio'), 'Vila Santo Antônio');
      expect(_name('Sta Filomena'), 'Santa Filomena');
      expect(_name('Bosque Saude'), 'Bosque da Saúde');
      expect(_name('Bosque de Saúde'), 'Bosque da Saúde');
      expect(_name('Vista Alegre 2'), 'Vista Alegre II');
      expect(_name('boa  vista!'), 'Boa Vista');
    });

    test('o nome exato ganha das aproximações', () {
      // "Jardim Americano" também tem as palavras de "Jardim América".
      expect(_name('Jardim América'), 'Jardim América');
      expect(_name('Jd America'), 'Jardim América');
      expect(_name('Jardim Americano'), 'Jardim Americano');
      expect(_name('Parque das Flores'), 'Parque das Flores');
    });

    test('aceita um único candidato próximo', () {
      expect(_name('Ercilia'), 'Vila Ercília'); // palavras contidas
      expect(_name('Toninho'), 'Vila Toninho');
      expect(_name('jd nazaret'), 'Jardim Nazareth'); // uma letra
      expect(_name('Higienopoles'), 'Higienópolis');
    });

    test('não escolhe quando há mais de um candidato', () {
      // Vila Redentora e Nova Redentora.
      expect(_name('Redentora'), isNull);
      // Jardim Karina 1, 2 e 3: número diferente não é erro de digitação.
      expect(_name('Jardim Karina'), isNull);
      expect(_name('Jardim Karina 4'), isNull);
      expect(_name('Santa Cruz'), isNull);
      expect(_name('Sul'), isNull);
    });

    test('bairro desconhecido fica sem posição (nada de centro da cidade)', () {
      expect(_name('Bairro Inventado'), isNull);
      expect(Places.approximatePosition('Bairro Inventado', 'a@b.c'), isNull);
      expect(Places.approximatePosition('', 'a@b.c'), isNull);
      expect(
        Places.approximatePosition('Jd. Nazareth', 'a@b.c'),
        Places.approximatePosition('Jardim Nazareth', 'a@b.c'),
      );
    });

    test('sugestões acham pelo nome abreviado', () {
      expect(
        Places.searchNeighborhoods('Jd Nazar'),
        contains('Jardim Nazareth'),
      );
    });

    test('aviso do campo "Bairro"', () {
      expect(neighborhoodHint('Boa Vista'), isNull);
      expect(neighborhoodHint('B'), isNull);
      expect(neighborhoodHint('Bairro Inventado'), kUnknownNeighborhoodHint);
      expect(
        neighborhoodHint('Jd. Nazareth'),
        'Vamos usar o bairro Jardim Nazareth no mapa.',
      );
    });
  });

  group('posição aproximada no modo local', () {
    setUp(() async {
      await useLocalBackend();
      await signInDemo();
    });

    test('editar o bairro no perfil recalcula a posição aproximada', () async {
      final auth = AuthService.instance;
      final email = auth.userEmail;
      expect(auth.location, Places.approximatePosition('Boa Vista', email));

      await auth.updateProfile(neighborhood: 'Vl Toninho');
      expect(auth.location, Places.approximatePosition('Vila Toninho', email));
      final map = await NeighborhoodService.instance.loadMap();
      expect(map.myLat, auth.location!.lat);
      expect(map.myLon, auth.location!.lon);

      // Bairro fora da lista: sem posição, fora do mapa dos vizinhos.
      await auth.updateProfile(neighborhood: 'Bairro Inventado');
      expect(auth.location, isNull);
      final unknown = await NeighborhoodService.instance.loadMap();
      expect(unknown.myLat, isNull);
      expect(unknown.centerLat, Places.cityCenter.lat);
      await NeighborhoodService.instance.load();
      expect(
        NeighborhoodService.instance.collectionPoints.every(
          (p) => p.distanceMeters == null,
        ),
        isTrue,
      );
    });

    test(
      'cadastro com bairro fora da lista não aparece para os outros',
      () async {
        await AuthService.instance.logout();
        await AuthService.instance.register(
          name: 'Bruno Lima',
          email: 'bruno@eco.app',
          password: 'segredo123',
          neighborhood: 'Bairro Inventado',
        );
        expect(AuthService.instance.location, isNull);

        await AuthService.instance.logout();
        await signInDemo();
        final map = await NeighborhoodService.instance.loadMap();
        expect(map.neighbors.where((n) => n.name.startsWith('Bruno')), isEmpty);
      },
    );
  });
}
