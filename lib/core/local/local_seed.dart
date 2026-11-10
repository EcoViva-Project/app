import 'dart:convert';

import 'data/collection_points_data.dart';
import 'economy.dart';
import 'local_api.dart';
import 'local_store.dart';

/// Dados de demonstração do modo local.
///
/// O histórico é gerado passando pelas mesmas regras do aplicativo (limites por
/// ação, teto semanal, desafios e conquistas), sempre relativo ao momento da
/// carga. Assim a conta de demonstração fica coerente em qualquer dia.
class LocalSeed {
  LocalSeed._();

  static const String demoEmail = 'clara@eco.app';
  static const String demoPassword = 'eco1234';

  /// Código de conferência usado por todos os parceiros de demonstração.
  static const String demoPartnerPin = '1234';

  /// Quantos pontos ficam livres abaixo do teto na semana atual, para a
  /// apresentação conseguir mostrar o teto sendo atingido.
  static const int _roomBelowCap = 25;

  static const List<Map<String, Object?>> actions = [
    {
      'title': 'Fechar a torneira ao escovar os dentes',
      'description': 'Economia estimada de 12 litros de água por escovação.',
      'category': 'agua',
      'category_label': 'Água',
      'icon': 'water_drop',
      'points': 5,
      'liters': 12,
      'daily_limit': 2,
      'weekly_limit': null,
      'info': 'Hábito diário',
      'info_icon': 'schedule',
      'tags': ['agua', 'torneira', 'dentes', 'banho'],
      'footer_info': 'Cerca de 12 L poupados por vez',
      'footer_icon': 'water_drop_outlined',
    },
    {
      'title': 'Separar resíduos secos e orgânicos',
      'description': 'Destino correto de plástico, papel, vidro e metal.',
      'category': 'reciclagem',
      'category_label': 'Reciclagem',
      'icon': 'recycling',
      'points': 15,
      'liters': 0,
      'daily_limit': 1,
      'weekly_limit': null,
      'info': 'Coleta seletiva',
      'info_icon': 'recycling',
      'tags': ['reciclagem', 'lixo', 'residuos', 'secos', 'organicos'],
      'footer_info': 'Evita cerca de 0,8 kg de CO₂ equivalente',
      'footer_icon': 'eco',
    },
    {
      'title': 'Deslocamento a pé ou de bicicleta',
      'description': 'Trajeto de até 5 km sem emissões diretas de carbono.',
      'category': 'transporte',
      'category_label': 'Transporte',
      'icon': 'directions_bike',
      'points': 30,
      'liters': 0,
      'daily_limit': 2,
      'weekly_limit': null,
      'info': 'Saúde e ar limpo',
      'info_icon': 'favorite',
      'tags': ['transporte', 'bicicleta', 'bike', 'caminhada', 'pe', 'mobilidade'],
      'footer_info': 'Cada trajeto conta uma vez',
      'footer_icon': 'route',
    },
    {
      'title': 'Compostagem de resíduos orgânicos',
      'description': 'Cascas, borra de café e restos vegetais viram adubo.',
      'category': 'alimentacao',
      'category_label': 'Alimentação',
      'icon': 'compost',
      'points': 25,
      'liters': 0,
      'daily_limit': 1,
      'weekly_limit': null,
      'info': 'Nutrientes de volta ao solo',
      'info_icon': 'yard',
      'tags': ['alimentacao', 'compostagem', 'comida', 'horta', 'adubo'],
      'footer_info': 'Reduz até 45% do lixo doméstico',
      'footer_icon': 'check_circle',
    },
    {
      'title': 'Apagar luzes em cômodos vazios',
      'description': 'Eficiência energética e menos consumo no mês.',
      'category': 'energia',
      'category_label': 'Energia',
      'icon': 'lightbulb_outline',
      'points': 5,
      'liters': 0,
      'daily_limit': 1,
      'weekly_limit': null,
      'info': 'Consumo consciente',
      'info_icon': 'bolt',
      'tags': ['energia', 'luz', 'comodo', 'eletricidade', 'lampada'],
      'footer_info': 'Até 10% de alívio na conta de luz',
      'footer_icon': 'savings',
    },
    {
      'title': 'Mutirão de limpeza de praça pública',
      'description': 'Cuidado com canteiros, descarte e áreas comuns do bairro.',
      'category': 'publico',
      'category_label': 'Espaços Públicos',
      'icon': 'park',
      'points': 100,
      'liters': 0,
      'daily_limit': null,
      'weekly_limit': 1,
      'info': 'Ação coletiva',
      'info_icon': 'diversity_1',
      'tags': ['publico', 'praca', 'parque', 'mutirao', 'comunidade', 'limpeza'],
      'footer_info': 'Cerca de 2 horas de trabalho em grupo',
      'footer_icon': 'groups',
    },
  ];

  static const List<Map<String, Object?>> challenges = [
    {
      'title': 'Semana sem desperdício de água',
      'description':
          'Registre pelo menos uma ação de Água por dia, durante 7 dias.',
      'category': 'Água',
      'icon': 'water_drop',
      'target_steps': 7,
      'step_mode': 'days',
      'points_reward': 100,
      'base_participants': 0,
      'duration_days': 7,
      'is_weekly': 1,
    },
    {
      'title': 'Transporte ativo no bairro',
      'description':
          'Faça 5 trajetos curtos a pé ou de bicicleta em até 7 dias.',
      'category': 'Transporte',
      'icon': 'directions_bike',
      'target_steps': 5,
      'step_mode': 'actions',
      'points_reward': 100,
      'base_participants': 0,
      'duration_days': 7,
      'is_weekly': 1,
    },
    {
      'title': 'Mutirão da praça central',
      'description':
          'Participe de um mutirão de limpeza ou plantio na praça do bairro.',
      'category': 'Espaços Públicos',
      'icon': 'park',
      'target_steps': 1,
      'step_mode': 'actions',
      'points_reward': 60,
      'base_participants': 0,
      'duration_days': 14,
      'is_weekly': 0,
    },
    {
      'title': 'Desafio da compostagem',
      'description':
          'Registre a compostagem em 10 dias diferentes, em até 14 dias.',
      'category': 'Alimentação',
      'icon': 'compost',
      'target_steps': 10,
      'step_mode': 'days',
      'points_reward': 150,
      'base_participants': 0,
      'duration_days': 14,
      'is_weekly': 0,
    },
  ];

  static const List<Map<String, Object?>> partners = [
    {
      'name': 'Restaurante Sabor da Terra',
      'description': 'Cozinha caseira com ingredientes de produtores do bairro.',
      'logo_icon': 'restaurant',
      'address': 'Rua do Mercado, 210',
    },
    {
      'name': 'Café Raízes',
      'description': 'Cafeteria de bairro com grãos de produtores locais.',
      'logo_icon': 'local_cafe',
      'address': 'Praça Central, 45',
    },
    {
      'name': 'Mercado Verde',
      'description': 'Mercearia sustentável com produtos a granel e orgânicos.',
      'logo_icon': 'storefront',
      'address': 'Rua das Acácias, 120',
    },
    {
      'name': 'Bike Urbana',
      'description': 'Oficina e loja de bicicletas para mobilidade ativa.',
      'logo_icon': 'directions_bike',
      'address': 'Avenida dos Ipês, 800',
    },
    {
      'name': 'Floresta Games',
      'description': 'Estúdio de jogos com temáticas ambientais.',
      'logo_icon': 'sports_esports',
      'address': 'Loja virtual',
    },
    {
      'name': 'EcoClean Serviços',
      'description': 'Limpeza ecológica residencial com produtos biodegradáveis.',
      'logo_icon': 'cleaning_services',
      'address': 'Atendimento em domicílio',
    },
  ];

  /// Preço dos cupons: valor do benefício em reais × [Economy.pointsPerReal].
  /// Itens digitais têm 20% de desconto, porque não têm custo por unidade.
  static const List<Map<String, Object?>> rewards = [
    {
      'partner': 'Restaurante Sabor da Terra',
      'title': '20% de desconto no almoço executivo',
      'description':
          'Desconto de 20% em um almoço executivo, de segunda a sexta.',
      'category': 'desconto',
      'category_label': 'Desconto',
      'icon': 'percent',
      'value_cents': 700,
      'points_cost': 350,
      'stock': 80,
      'terms': 'Um cupom por mesa. Não vale em feriados.',
      'validity_days': 30,
      'per_user_limit': 2,
      'is_featured': 1,
    },
    {
      'partner': 'Restaurante Sabor da Terra',
      'title': 'Sobremesa da casa grátis',
      'description': 'Uma sobremesa da casa no almoço ou no jantar.',
      'category': 'gastronomia',
      'category_label': 'Gastronomia',
      'icon': 'restaurant',
      'value_cents': 1200,
      'points_cost': 600,
      'stock': 40,
      'terms': 'Válido com o pedido de um prato principal.',
      'validity_days': 30,
      'per_user_limit': 2,
      'is_featured': 0,
    },
    {
      'partner': 'Restaurante Sabor da Terra',
      'title': 'Prato do dia vegetariano grátis',
      'description': 'Um prato do dia vegetariano, com ingredientes da estação.',
      'category': 'gastronomia',
      'category_label': 'Gastronomia',
      'icon': 'restaurant',
      'value_cents': 3200,
      'points_cost': 1600,
      'stock': 20,
      'terms': 'Válido no almoço, de segunda a sábado.',
      'validity_days': 30,
      'per_user_limit': 1,
      'is_featured': 1,
    },
    {
      'partner': 'Café Raízes',
      'title': '15% de desconto no combo',
      'description': 'Desconto em qualquer combo de café com pão artesanal.',
      'category': 'desconto',
      'category_label': 'Desconto',
      'icon': 'percent',
      'value_cents': 400,
      'points_cost': 200,
      'stock': 100,
      'terms': 'Não cumulativo com outras promoções.',
      'validity_days': 30,
      'per_user_limit': 2,
      'is_featured': 0,
    },
    {
      'partner': 'Café Raízes',
      'title': 'Café especial grátis',
      'description': 'Um café coado especial de 200 ml na unidade do bairro.',
      'category': 'gastronomia',
      'category_label': 'Gastronomia',
      'icon': 'local_cafe',
      'value_cents': 900,
      'points_cost': 450,
      'stock': 60,
      'terms': 'Válido de segunda a sexta, das 8h às 17h.',
      'validity_days': 30,
      'per_user_limit': 2,
      'is_featured': 0,
    },
    {
      'partner': 'Mercado Verde',
      'title': 'Kit de sacolas reutilizáveis',
      'description':
          'Três sacolas de algodão orgânico para as compras do dia a dia.',
      'category': 'produto',
      'category_label': 'Produto',
      'icon': 'shopping_bag',
      'value_cents': 3000,
      'points_cost': 1500,
      'stock': 25,
      'terms': 'Retire na loja dentro da validade do cupom.',
      'validity_days': 30,
      'per_user_limit': 1,
      'is_featured': 1,
    },
    {
      'partner': 'Mercado Verde',
      'title': 'Cesta de hortifrúti orgânico',
      'description':
          'Seleção de frutas e verduras cultivadas por produtores locais.',
      'category': 'produto',
      'category_label': 'Produto',
      'icon': 'eco',
      'value_cents': 6000,
      'points_cost': 3000,
      'stock': 10,
      'terms': 'Retirada agendada. Sujeito à disponibilidade da safra.',
      'validity_days': 30,
      'per_user_limit': 1,
      'is_featured': 0,
    },
    {
      'partner': 'Floresta Games',
      'title': 'Skin Guardião da Floresta',
      'description': 'Pacote de cosméticos digitais do jogo Floresta Viva.',
      'category': 'jogo',
      'category_label': 'Jogo',
      'icon': 'sports_esports',
      'value_cents': 2000,
      'points_cost': 800,
      'stock': 40,
      'terms': 'Código de uso único, vinculado à sua conta no jogo.',
      'validity_days': 60,
      'per_user_limit': 1,
      'is_featured': 0,
    },
    {
      'partner': 'Floresta Games',
      'title': 'Passe de temporada Floresta Viva',
      'description': 'Passe de temporada com missões e recompensas temáticas.',
      'category': 'jogo',
      'category_label': 'Jogo',
      'icon': 'sports_esports',
      'value_cents': 4000,
      'points_cost': 1600,
      'stock': 5,
      'terms': 'Código de uso único, vinculado à sua conta no jogo.',
      'validity_days': 60,
      'per_user_limit': 1,
      'is_featured': 0,
    },
    {
      'partner': 'Bike Urbana',
      'title': 'Revisão básica de bicicleta',
      'description': 'Ajuste de freios, transmissão e calibragem dos pneus.',
      'category': 'servico',
      'category_label': 'Serviço',
      'icon': 'directions_bike',
      'value_cents': 6000,
      'points_cost': 3000,
      'stock': 12,
      'terms': 'Peças não inclusas. Agende pelo telefone da oficina.',
      'validity_days': 45,
      'per_user_limit': 1,
      'is_featured': 0,
    },
    {
      'partner': 'Bike Urbana',
      'title': 'Camisa oficial EcoViva',
      'description': 'Camisa de algodão reciclado das pedaladas comunitárias.',
      'category': 'produto',
      'category_label': 'Produto',
      'icon': 'checkroom',
      'value_cents': 5000,
      'points_cost': 2500,
      'stock': 0,
      'terms': 'Tamanhos sujeitos ao estoque disponível.',
      'validity_days': 30,
      'per_user_limit': 1,
      'is_featured': 0,
    },
    {
      'partner': 'EcoClean Serviços',
      'title': 'Limpeza ecológica residencial',
      'description': 'Duas horas de limpeza com produtos biodegradáveis.',
      'category': 'servico',
      'category_label': 'Serviço',
      'icon': 'cleaning_services',
      'value_cents': 16000,
      'points_cost': 8000,
      'stock': 8,
      'terms': 'Agendamento com antecedência mínima de 3 dias.',
      'validity_days': 60,
      'per_user_limit': 1,
      'is_featured': 0,
    },
  ];

  static Future<void> run(LocalApi api) async {
    await api.db.bulk(() => _seed(api));
  }

  /// Só o catálogo (ações, desafios, parceiros e recompensas), sem usuários.
  static Future<void> seedCatalog(LocalApi api, DateTime createdAt) async {
    final db = api.db;
    final created = createdAt.toUtc().toIso8601String();

    for (final action in actions) {
      await db.insert('actions', {
        ...action,
        'tags': jsonEncode(action['tags']),
      });
    }
    for (final challenge in challenges) {
      await db.insert('challenges', challenge);
    }
    final partnerIds = <String, Object?>{};
    for (final partner in partners) {
      final row = await db.insert('partners', {
        ...partner,
        'pin': demoPartnerPin,
        'created_at': created,
      });
      partnerIds['${partner['name']}'] = row['id'];
    }
    for (final reward in rewards) {
      final values = Map<String, Object?>.from(reward)..remove('partner');
      await db.insert('rewards', {
        ...values,
        'partner_id': partnerIds['${reward['partner']}'],
        'active': 1,
        'created_at': created,
      });
    }

    await db.insert('community_goals', {
      'title': 'Meta coletiva da semana',
      'description':
          'Juntos, vamos registrar $weeklyGoalTarget ações sustentáveis até domingo.',
      'target_actions': weeklyGoalTarget,
      'active': 1,
    });
    for (final tip in tips) {
      await db.insert('tips', tip);
    }
    for (final point in collectionPointsData) {
      await db.insert('collection_points', {
        ...point,
        'materials': jsonEncode(point['materials'] ?? const <String>[]),
      });
    }
  }

  /// Meta coletiva: ações registradas por toda a comunidade na semana.
  static const int weeklyGoalTarget = 400;

  static const List<Map<String, Object?>> tips = [
    {
      'text':
          'Aproveite a água do enxágue de frutas e verduras para regar as plantas.',
      'category_label': 'Água',
      'icon': 'water_drop',
    },
    {
      'text':
          'Lave as embalagens antes de separar para a reciclagem: material limpo vale mais para a cooperativa.',
      'category_label': 'Reciclagem',
      'icon': 'recycling',
    },
    {
      'text':
          'Trajetos de até 2 km costumam ser mais rápidos a pé ou de bicicleta do que procurando vaga.',
      'category_label': 'Transporte',
      'icon': 'directions_bike',
    },
    {
      'text':
          'Cascas de frutas, borra de café e folhas secas são a base de uma boa composteira.',
      'category_label': 'Alimentação',
      'icon': 'compost',
    },
    {
      'text':
          'Tire da tomada os aparelhos que ficam em espera: eles consomem energia mesmo desligados.',
      'category_label': 'Energia',
      'icon': 'bolt',
    },
    {
      'text':
          'Leve uma sacola extra na caminhada e recolha o que encontrar pelo caminho.',
      'category_label': 'Espaços Públicos',
      'icon': 'park',
    },
    {
      'text':
          'Um banho de 5 minutos gasta cerca de um terço da água de um banho de 15.',
      'category_label': 'Água',
      'icon': 'water_drop',
    },
    {
      'text':
          'Óleo de cozinha usado não vai na pia: guarde em uma garrafa e leve a um ponto de coleta.',
      'category_label': 'Reciclagem',
      'icon': 'recycling',
    },
    {
      'text':
          'Combine carona com quem faz o mesmo trajeto: um carro a menos na rua todos os dias.',
      'category_label': 'Transporte',
      'icon': 'groups',
    },
    {
      'text':
          'Planeje as refeições da semana antes de ir ao mercado e evite jogar comida fora.',
      'category_label': 'Alimentação',
      'icon': 'eco',
    },
    {
      'text':
          'Aproveite a luz natural: abrir a cortina de manhã adia a hora de acender a lâmpada.',
      'category_label': 'Energia',
      'icon': 'lightbulb_outline',
    },
    {
      'text':
          'Pilhas, baterias e lâmpadas têm ponto de coleta próprio: nunca vão no lixo comum.',
      'category_label': 'Reciclagem',
      'icon': 'recycling',
    },
    {
      'text':
          'Adote um canteiro ou uma árvore da sua rua: regar uma vez por semana já ajuda.',
      'category_label': 'Espaços Públicos',
      'icon': 'park',
    },
    {
      'text':
          'Feche a torneira ao ensaboar a louça e economize dezenas de litros por lavagem.',
      'category_label': 'Água',
      'icon': 'water_drop',
    },
  ];

  /// Moradores fictícios da demonstração, em bairros reais de Rio Preto.
  ///
  /// O terceiro valor é o ritmo: 1 = casual, 2 = regular, 3 = dedicado.
  static const List<(String, String, int)> neighbors = [
    ('Marina Lopes', 'Vila Redentora', 3),
    ('Rafael Souza', 'Higienópolis', 2),
    ('João Ferreira', 'Jardim Alto Rio Preto', 2),
    ('Beatriz Nunes', 'Vila Imperial', 3),
    ('Carlos Eduardo Lima', 'Eldorado', 1),
    ('Fernanda Rocha', 'Solo Sagrado', 2),
    ('Gustavo Almeida', 'Jardim Nazareth', 1),
    ('Helena Barros', 'Vila Maceno', 2),
    ('Igor Santana', 'Jardim Yolanda', 1),
    ('Juliana Prado', 'Vila Anchieta', 3),
    ('Lucas Teixeira', 'Jardim Canaã', 2),
    ('Mariana Costa', 'Jardim Soraia', 1),
    ('Nelson Ribeiro', 'Parque Industrial', 2),
    ('Olívia Martins', 'Vila Ercília', 2),
    ('Paulo Henrique Dias', 'São Francisco', 1),
    ('Renata Cardoso', 'Vila Toninho', 2),
    ('Sérgio Moura', 'Jardim Vetorasso', 1),
    ('Tatiane Freitas', 'Centro', 3),
  ];

  static Future<void> _seed(LocalApi api) async {
    final db = api.db;
    final now = api.now;
    const day = Duration(days: 1);
    final today = Economy.startOfLocalDay(now);
    final weekStart = today.subtract(
      Duration(days: Economy.wallClock(now).weekday - DateTime.monday),
    );
    const historyDays = 63;
    final firstDay = today.subtract(const Duration(days: historyDays));

    await seedCatalog(api, firstDay);

    final clara = await api.createUser(
      name: 'Clara Mendes',
      email: demoEmail,
      password: demoPassword,
      neighborhood: 'Boa Vista',
      createdAt: firstDay.add(const Duration(hours: 7)),
    );
    // Meta mensal compatível com o ritmo da conta de demonstração.
    await db.update('users', clara, {'monthly_goal': 120, 'weekly_goal': 25});

    DbRow action(int number) => db.byId('actions', number)!;
    DbRow challenge(int number) => db.byId('challenges', number)!;
    DbRow reward(String title) =>
        db.table('rewards').firstWhere((r) => r['title'] == title);

    Future<void> register(
      int actionNumber,
      DateTime at, {
      int quantity = 1,
      bool currentWeek = false,
    }) async {
      if (at.isAfter(now)) return;
      final row = action(actionNumber);
      if (currentWeek) {
        final points = (row['points'] as int) * quantity;
        if (api.weekActionPoints(clara['id'], at) + points >
            Economy.weeklyCap - _roomBelowCap) {
          return;
        }
      }
      try {
        await api.registerAction(
          clara,
          row,
          quantity: quantity,
          at: at,
          silent: true,
        );
      } on Object {
        // Um registro que esbarra em limite é simplesmente ignorado.
      }
    }

    // ----- Semanas anteriores: ritmo de uma usuária regular -----
    final transportChallengeWeek = weekStart.subtract(const Duration(days: 35));
    final expiredCouponDay = weekStart.subtract(const Duration(days: 40));
    final usedCouponDay = weekStart.subtract(const Duration(days: 18));

    for (var d = firstDay; d.isBefore(weekStart); d = d.add(day)) {
      final weekday = Economy.wallClock(d).weekday;
      final weeksAgo = weekStart.difference(d).inDays ~/ 7 + 1;
      final inChallengeWeek =
          !d.isBefore(transportChallengeWeek) &&
          d.isBefore(transportChallengeWeek.add(const Duration(days: 7)));

      if (d == transportChallengeWeek) {
        await api.joinChallenge(
          clara,
          challenge(2),
          at: d.add(const Duration(hours: 7)),
        );
      }

      await register(1, d.add(const Duration(hours: 7, minutes: 30)));
      await register(1, d.add(const Duration(hours: 21, minutes: 40)));
      await register(2, d.add(const Duration(hours: 12, minutes: 10)));
      if (weekday == DateTime.monday ||
          weekday == DateTime.wednesday ||
          weekday == DateTime.friday) {
        await register(
          3,
          d.add(const Duration(hours: 18, minutes: 20)),
          quantity: inChallengeWeek ? 2 : 1,
        );
      }
      if (weekday == DateTime.tuesday || weekday == DateTime.saturday) {
        await register(4, d.add(const Duration(hours: 19, minutes: 40)));
      }
      if (weekday == DateTime.thursday && weeksAgo.isEven) {
        await register(5, d.add(const Duration(hours: 22)));
      }
      if (weekday == DateTime.sunday && weeksAgo % 3 == 0) {
        await register(6, d.add(const Duration(hours: 9)));
      }

      if (d == expiredCouponDay) {
        await _redeem(
          api,
          clara,
          reward('15% de desconto no combo'),
          d.add(const Duration(hours: 13)),
        );
      }
      if (d == usedCouponDay) {
        final redemption = await _redeem(
          api,
          clara,
          reward('Café especial grátis'),
          d.add(const Duration(hours: 13)),
        );
        if (redemption != null) {
          await api.markRedemptionUsed(
            redemption,
            at: d.add(const Duration(days: 2, hours: 9)),
          );
        }
      }
    }

    // ----- Semana atual: dias cheios em ritmo forte, para chegar perto do teto -----
    if (!weekStart.isAfter(now)) {
      await api.joinChallenge(
        clara,
        challenge(1),
        at: weekStart.add(const Duration(minutes: 5)),
      );
    }
    final yesterday = today.subtract(day);
    for (var d = weekStart; d.isBefore(today); d = d.add(day)) {
      final isMonday = Economy.wallClock(d).weekday == DateTime.monday;
      await register(
        1,
        d.add(const Duration(hours: 7, minutes: 30)),
        currentWeek: true,
      );
      await register(
        1,
        d.add(const Duration(hours: 21, minutes: 40)),
        currentWeek: true,
      );
      await register(
        2,
        d.add(const Duration(hours: 12, minutes: 10)),
        currentWeek: true,
      );
      await register(
        4,
        d.add(const Duration(hours: 19, minutes: 40)),
        currentWeek: true,
      );
      await register(
        3,
        d.add(const Duration(hours: 18, minutes: 20)),
        quantity: 2,
        currentWeek: true,
      );
      if (isMonday) {
        await register(5, d.add(const Duration(hours: 22)), currentWeek: true);
      }
      if (d == yesterday) {
        await register(6, d.add(const Duration(hours: 9)), currentWeek: true);
      }
    }

    // ----- Hoje: poucas ações, espalhadas pelo tempo já decorrido do dia -----
    final elapsed = now.difference(today);
    DateTime todayAt(double fraction) => today.add(
      Duration(seconds: (elapsed.inSeconds * fraction).round()),
    );
    await register(1, todayAt(0.3), currentWeek: true);
    await register(2, todayAt(0.5), currentWeek: true);
    await register(3, todayAt(0.7), currentWeek: true);

    await _attachExamplePhotos(api, clara);

    // Um cupom ainda válido, resgatado há três dias.
    await _redeem(
      api,
      clara,
      reward('20% de desconto no almoço executivo'),
      now.subtract(const Duration(days: 3, hours: 2)),
    );

    final people = await _seedNeighbors(api, today, weekStart);
    await _seedCommunity(api, clara, now, people);
    await _seedNotifications(api, clara, now, firstDay);
  }

  /// Fotos de exemplo (desenhadas pelo próprio projeto) para a demonstração
  /// já mostrar o selo de comprovação: a ação de cada foto e o arquivo.
  static const Map<int, String> examplePhotos = {
    2: 'assets/fotos_exemplo/separacao.png',
    3: 'assets/fotos_exemplo/bicicleta.png',
    4: 'assets/fotos_exemplo/composteira.png',
  };

  /// Liga cada foto de exemplo ao registro mais recente da ação dela.
  static Future<void> _attachExamplePhotos(LocalApi api, DbRow clara) async {
    for (final entry in examplePhotos.entries) {
      DbRow? latest;
      for (final row in api.db.table('action_records')) {
        if (row['user_id'] != clara['id'] || row['action_id'] != entry.key) {
          continue;
        }
        if (latest == null ||
            '${row['created_at']}'.compareTo('${latest['created_at']}') > 0) {
          latest = row;
        }
      }
      if (latest == null) continue;
      await api.attachPhoto(
        latest,
        asset: entry.value,
        at: DateTime.parse('${latest['created_at']}'),
      );
    }
  }

  /// Cria os moradores fictícios e as duas últimas semanas de ações deles,
  /// passando pelas mesmas regras de qualquer usuário. É daqui que saem os
  /// números do bairro: vizinhos ativos, ações da semana, meta coletiva,
  /// ranking e "quantos registraram hoje".
  static Future<Map<String, DbRow>> _seedNeighbors(
    LocalApi api,
    DateTime today,
    DateTime weekStart,
  ) async {
    final db = api.db;
    final now = api.now;
    const day = Duration(days: 1);
    final firstDay = today.subtract(const Duration(days: 13));
    final people = <String, DbRow>{};

    // Gerador simples e determinístico: a demonstração é sempre a mesma.
    var state = 20261111;
    int next(int max) {
      state = (state * 1103515245 + 12345) & 0x7fffffff;
      return (state >> 8) % max;
    }

    DbRow action(int number) => db.byId('actions', number)!;

    for (var i = 0; i < neighbors.length; i++) {
      final (name, neighborhood, pace) = neighbors[i];
      final person = await api.createUser(
        name: name,
        email: 'vizinho${i + 1}@demo.ecoviva',
        // Contas de figuração: ninguém entra com elas.
        password: 'figurante-${state + i}',
        neighborhood: neighborhood,
        createdAt: firstDay.subtract(Duration(days: 20 + i)),
      );
      people[name] = person;

      Future<void> register(int number, DateTime at, {int quantity = 1}) async {
        if (at.isAfter(now)) return;
        try {
          await api.registerAction(
            person,
            action(number),
            quantity: quantity,
            at: at,
            silent: true,
          );
        } on Object {
          // Limite da ação ou do dia: o registro é ignorado.
        }
      }

      // Entradas em desafios, para a contagem de participantes ser real.
      final joins = <int, DateTime>{
        if (i < 9) 1: weekStart.add(Duration(minutes: 10 + i)),
        if (i >= 3 && i < 10) 2: today.subtract(const Duration(days: 5)),
        if (i >= 10 && i < 14) 3: today.subtract(const Duration(days: 6)),
        if (i >= 12) 4: today.subtract(const Duration(days: 4)),
      };
      for (final entry in joins.entries) {
        if (entry.value.isAfter(now)) continue;
        await api.joinChallenge(
          person,
          db.byId('challenges', entry.key)!,
          at: entry.value,
        );
      }

      final elapsedToday = now.difference(today);
      for (var d = firstDay; !d.isAfter(today); d = d.add(day)) {
        final isToday = d == today;
        final activeChance = pace == 3 ? 95 : (pace == 2 ? 75 : 45);
        final roll = next(100);
        if (roll >= activeChance) continue;

        // Hoje as ações se espalham pelo tempo já decorrido do dia.
        DateTime at(int hour, int minute) {
          if (!isToday) return d.add(Duration(hours: hour, minutes: minute));
          final fraction = ((hour - 6) / 17).clamp(0.05, 0.95);
          return today.add(
            Duration(seconds: (elapsedToday.inSeconds * fraction).round()),
          );
        }

        await register(1, at(7, 20 + i));
        if (pace >= 2) await register(1, at(21, 10 + i));
        if (next(100) < 40 + pace * 15) await register(2, at(12, i));
        if (next(100) < 15 + pace * 15) {
          await register(3, at(18, i), quantity: pace == 3 ? 2 : 1);
        }
        if (next(100) < 10 + pace * 12) await register(4, at(19, 30));
        if (next(100) < 20 + pace * 10) await register(5, at(22, 0));
        if (pace == 3 &&
            Economy.wallClock(d).weekday == DateTime.sunday) {
          await register(6, at(9, 0));
        }
      }
    }
    return people;
  }

  static Future<DbRow?> _redeem(
    LocalApi api,
    DbRow user,
    DbRow reward,
    DateTime at,
  ) async {
    if (at.isAfter(api.now)) return null;
    try {
      return await api.redeemReward(user, reward, at: at, silent: true);
    } on Object {
      return null;
    }
  }

  static Future<void> _seedCommunity(
    LocalApi api,
    DbRow clara,
    DateTime now,
    Map<String, DbRow> people,
  ) async {
    final db = api.db;
    String ago(Duration duration) =>
        now.subtract(duration).toUtc().toIso8601String();

    Future<void> post({
      required String name,
      required String initials,
      required String content,
      required int likes,
      required Duration age,
      Object? userId,
      List<(String, String, String, Duration)> comments = const [],
    }) async {
      final row = await db.insert('posts', {
        // As publicações dos vizinhos pertencem às contas deles.
        'user_id': userId ?? people[name]?['id'],
        'author_name': name,
        'author_initials': initials,
        'content': content,
        'base_likes': likes,
        'created_at': ago(age),
      });
      for (final (author, authorInitials, text, commentAge) in comments) {
        await db.insert('post_comments', {
          'post_id': row['id'],
          'user_id': null,
          'author_name': author,
          'author_initials': authorInitials,
          'content': text,
          'created_at': ago(commentAge),
        });
      }
      if (userId != null) {
        await db.insert('post_likes', {'post_id': row['id'], 'user_id': userId});
      }
    }

    await post(
      name: 'Marina Lopes',
      initials: 'ML',
      content:
          'Comecei a compostar na varanda e em duas semanas o lixo orgânico da casa caiu pela metade. Quem quiser dicas, chama!',
      likes: 34,
      age: const Duration(hours: 3),
      comments: [
        (
          'Rafael Souza',
          'RS',
          'Adorei! Vou tentar aqui também.',
          const Duration(hours: 2),
        ),
      ],
    );
    await post(
      name: 'Rafael Souza',
      initials: 'RS',
      content:
          'Mutirão de limpeza da praça neste sábado às 9h. Levem luvas e sacolas, a prefeitura recolhe o material no fim da manhã.',
      likes: 51,
      age: const Duration(hours: 8),
      comments: [
        (
          'Marina Lopes',
          'ML',
          'Vou levar as crianças para ajudar.',
          const Duration(hours: 4),
        ),
      ],
    );
    await post(
      name: 'João Ferreira',
      initials: 'JF',
      content:
          'Troquei o carro pela bike em trajetos de até 5 km. Em um mês foram 18 trajetos e muita disposição a mais.',
      likes: 28,
      age: const Duration(hours: 26),
    );
    await post(
      name: '${clara['name']}',
      initials: '${clara['initials']}',
      userId: clara['id'],
      content:
          'Fechando a torneira todos os dias já passei de mil litros de água poupados. Pequenas atitudes somam muito!',
      likes: 19,
      age: const Duration(hours: 50),
      comments: [
        (
          'João Ferreira',
          'JF',
          'Excelente, Clara! Bora manter o ritmo.',
          const Duration(hours: 48),
        ),
      ],
    );
  }

  static Future<void> _seedNotifications(
    LocalApi api,
    DbRow clara,
    DateTime now,
    DateTime firstDay,
  ) async {
    await api.notify(
      clara,
      'sistema',
      'Boas-vindas ao EcoViva!',
      'Sua conta de demonstração está pronta, com histórico, desafios, comunidade e cupons.',
      target: '/acoes',
      at: firstDay.add(const Duration(hours: 7)),
      read: true,
    );
    await api.notify(
      clara,
      'recompensa',
      'Resgate confirmado!',
      'Você resgatou "20% de desconto no almoço executivo" com Restaurante Sabor da Terra.',
      target: '/recompensas',
      at: now.subtract(const Duration(days: 3, hours: 2)),
      read: true,
    );
    await api.notify(
      clara,
      'comunidade',
      'Novo comentário',
      'João Ferreira comentou na sua publicação.',
      target: '/comunidade',
      at: now.subtract(const Duration(hours: 48)),
    );
    await api.notify(
      clara,
      'desafio',
      'Desafio em andamento',
      'Continue registrando ações de Água para concluir "Semana sem desperdício de água".',
      target: '/desafios',
      at: now.subtract(const Duration(hours: 5)),
    );
    await api.notify(
      clara,
      'sistema',
      'Você está perto do teto da semana',
      'Faltam poucos pontos para os ${Economy.weeklyCap} desta semana. As ações continuam valendo para desafios e conquistas.',
      target: '/progresso',
      at: now.subtract(const Duration(minutes: 40)),
    );
  }
}
