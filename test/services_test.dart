import 'package:eco_app/core/services/achievement_service.dart';
import 'package:eco_app/core/services/action_catalog_service.dart';
import 'package:eco_app/core/services/action_history_service.dart';
import 'package:eco_app/core/services/api_client.dart';
import 'package:eco_app/core/services/auth_service.dart';
import 'package:eco_app/core/services/challenge_service.dart';
import 'package:eco_app/core/services/community_service.dart';
import 'package:eco_app/core/services/notification_service.dart';
import 'package:eco_app/core/services/reward_service.dart';
import 'package:eco_app/core/services/user_progress_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/local_app.dart';

void main() {
  setUp(() async {
    await useLocalBackend();
  });

  test('antes do login os serviços ficam vazios, sem dados de exemplo', () {
    expect(AuthService.instance.isAuthenticated, isFalse);
    expect(UserProgressService.instance.isLoaded, isFalse);
    expect(UserProgressService.instance.points, 0);
    expect(AchievementService.instance.achievements, isEmpty);
    expect(NotificationService.instance.notifications, isEmpty);
    expect(RewardService.instance.rewards, isEmpty);
    expect(ActionCatalogService.instance.actions, isEmpty);
  });

  test('login carrega todos os módulos com os dados da conta', () async {
    await signInDemo();

    final auth = AuthService.instance;
    expect(auth.isAuthenticated, isTrue);
    expect(auth.firstName, 'Clara');
    expect(auth.userInitials, 'CM');

    final progress = UserProgressService.instance;
    expect(progress.isLoaded, isTrue);
    expect(progress.weeklyCap, 400);
    expect(progress.weeklyPoints, 375);
    expect(progress.weeklyRemaining, 25);
    expect(progress.capReached, isFalse);
    expect(progress.level, 'Árvore • Nível 4');
    expect(progress.nextLevelAt, 6000);
    expect(progress.levelProgress, inInclusiveRange(0.0, 1.0));
    expect(progress.weekResetsAt, isNotNull);

    expect(ActionCatalogService.instance.actions, hasLength(6));
    expect(
      ActionCatalogService.instance.categories.map((c) => c.label),
      contains('Água'),
    );
    expect(ActionHistoryService.instance.records, isNotEmpty);
    expect(AchievementService.instance.achievements, hasLength(10));
    expect(ChallengeService.instance.ongoing.single.id, 1);
    expect(ChallengeService.instance.completedChallenges.single.id, 2);
    expect(ChallengeService.instance.featured?.id, 1);
    expect(CommunityService.instance.posts, hasLength(4));
    expect(NotificationService.instance.unreadCount, 3);
    expect(RewardService.instance.rewards, hasLength(12));
    expect(RewardService.instance.activeCoupons, hasLength(1));
  });

  test('semana atual vem do histórico real', () async {
    await signInDemo();
    final week = ActionHistoryService.instance.currentWeek(
      now: demoNow.toLocal(),
    );
    expect(week, hasLength(7));
    expect(week.first.date.weekday, DateTime.monday);
    final total = week.fold<int>(0, (sum, day) => sum + day.points);
    expect(total, UserProgressService.instance.weeklyPoints);
    expect(ActionHistoryService.instance.actionsByCategory().first.key, 'Água');
  });

  test('registrar ação atualiza saldo, catálogo, conquistas e desafios', () async {
    await signInDemo();
    final history = ActionHistoryService.instance;
    final before = UserProgressService.instance.pointsEarned;

    // Apagar as luzes: +5 e destrava "Guardião da Energia" (+80 de bônus).
    final lights = await history.submitAction(actionId: 5, quantity: 1);
    expect(lights.record.points, 5);
    expect(lights.capReached, isFalse);
    expect(lights.newAchievements.single.key, 'guardiao-da-energia');
    expect(lights.bonusPoints, 80);
    expect(history.lastSubmission, same(lights));
    expect(UserProgressService.instance.pointsEarned, before + 85);
    expect(UserProgressService.instance.weeklyRemaining, 20);

    // Compostagem vale 25, mas só 20 cabem no teto.
    await ChallengeService.instance.join(4);
    final compost = await history.submitAction(actionId: 4, quantity: 1);
    expect(compost.record.basePoints, 25);
    expect(compost.record.points, 20);
    expect(compost.record.capped, isTrue);
    expect(compost.capReached, isTrue);
    expect(compost.challengeUpdates.single.id, 4);
    expect(compost.challengeUpdates.single.completedSteps, 1);
    expect(UserProgressService.instance.capReached, isTrue);
    expect(ChallengeService.instance.byId(4)!.stepDoneToday, isTrue);

    // O catálogo recarrega os limites da ação.
    await ActionCatalogService.instance.load();
    expect(ActionCatalogService.instance.byId(5)!.canRegister, isFalse);
    expect(ActionCatalogService.instance.byId(5)!.blockedLabel, 'Volta amanhã');
    await expectLater(
      history.submitAction(actionId: 5, quantity: 1),
      throwsA(isA<ApiException>()),
    );
  });

  test('resgatar cupom e conferir com o código do parceiro', () async {
    await signInDemo();
    final rewards = RewardService.instance;
    final balance = UserProgressService.instance.points;

    final dessert = rewards.rewards.firstWhere(
      (reward) => reward.title == 'Sobremesa da casa grátis',
    );
    expect(dessert.valueLabel, 'Vale R\$ 12,00');
    expect(dessert.category, RewardCategoryFilter.gastronomia.name);

    final coupon = await rewards.redeem(dessert);
    expect(coupon.code, startsWith('ECO-'));
    expect(coupon.status, CouponStatus.active);
    expect(coupon.statusDetail, startsWith('Válido até'));
    expect(UserProgressService.instance.points, balance - 600);
    expect(rewards.activeCoupons, hasLength(2));

    await expectLater(
      rewards.useCoupon(coupon, '0000'),
      throwsA(isA<ApiException>()),
    );
    final used = await rewards.useCoupon(coupon, '1234');
    expect(used.status, CouponStatus.used);
    expect(rewards.activeCoupons, hasLength(1));
    expect(
      rewards.redemptions.map((c) => c.status).toSet(),
      CouponStatus.values.toSet(),
    );
  });

  test('filtros de recompensas', () async {
    await signInDemo();
    final rewards = RewardService.instance;
    rewards.setCategory(RewardCategoryFilter.gastronomia);
    expect(rewards.rewards, hasLength(3));
    rewards.setSearch('cafe');
    expect(rewards.rewards.single.title, 'Café especial grátis');
    rewards.clearFilters();
    rewards.setSort(RewardSort.menorCusto);
    expect(rewards.rewards.first.pointsCost, 200);
    expect(rewards.availableCount, 11);
  });

  test('comunidade: publicar, curtir, comentar e excluir', () async {
    await signInDemo();
    final community = CommunityService.instance;
    final post = await community.createPost('Teste de publicação');
    expect(post.isMine, isTrue);
    expect(community.posts.first.id, post.id);

    await community.toggleLike(post.id);
    expect(community.byId(post.id)!.likedByMe, isTrue);
    expect(community.byId(post.id)!.likes, 1);

    await community.addComment(post.id, 'Boa!');
    final comment = community.byId(post.id)!.comments.single;
    expect(comment.authorName, 'Clara Mendes');
    expect(comment.timeLabel, 'Agora');

    await community.deletePost(post.id);
    expect(community.byId(post.id), isNull);
  });

  test('notificações: alterações persistem e erros são desfeitos', () async {
    await signInDemo();
    final notifications = NotificationService.instance;
    final first = notifications.notifications.first;
    expect(first.read, isFalse);
    expect(first.destination, startsWith('/'));

    await notifications.markAsRead(first.id);
    await notifications.load();
    expect(notifications.notifications.first.read, isTrue);

    await notifications.toggleRead(first.id);
    await notifications.load();
    expect(notifications.notifications.first.read, isFalse);

    await notifications.markAllAsRead();
    expect(notifications.unreadCount, 0);

    // Sessão inválida: a remoção é desfeita e o erro fica disponível.
    final count = notifications.notifications.length;
    final token = ApiClient.instance.token;
    ApiClient.instance.onUnauthorized = null;
    ApiClient.instance.setToken('local.999.x');
    await notifications.remove(first.id);
    expect(notifications.notifications, hasLength(count));
    expect(notifications.takeLastError(), isNotNull);
    ApiClient.instance.setToken(token);

    await notifications.clear();
    await notifications.load();
    expect(notifications.notifications, isEmpty);
  });

  test('sessão recusada pela API encerra o login', () async {
    await signInDemo();
    ApiClient.instance.setToken('local.999.x');
    await expectLater(
      UserProgressService.instance.load(),
      throwsA(isA<ApiException>()),
    );
    await Future<void>.delayed(Duration.zero);
    expect(AuthService.instance.isAuthenticated, isFalse);
    expect(UserProgressService.instance.isLoaded, isFalse);
  });

  test('restaurar a demonstração limpa a sessão e os dados', () async {
    await signInDemo();
    await ActionHistoryService.instance.submitAction(actionId: 5, quantity: 1);
    await AuthService.instance.resetDemo();
    expect(AuthService.instance.isAuthenticated, isFalse);
    expect(ActionHistoryService.instance.records, isEmpty);

    await signInDemo();
    expect(UserProgressService.instance.weeklyPoints, 375);
    expect(
      AchievementService.instance.achievements
          .firstWhere((a) => a.key == 'guardiao-da-energia')
          .isUnlocked,
      isFalse,
    );
  });

  test('editar perfil e preferências', () async {
    await signInDemo();
    await AuthService.instance.updateProfile(
      name: 'Clara M. Souza',
      neighborhood: 'Vila Verde',
      weeklyGoal: 7,
    );
    expect(AuthService.instance.userInitials, 'CS');
    expect(AuthService.instance.neighborhood, 'Vila Verde');
    expect(AuthService.instance.weeklyGoal, 7);
    await expectLater(
      AuthService.instance.updateProfile(name: 'A'),
      throwsA(isA<ApiException>()),
    );

    await AuthService.instance.updatePreferences({
      'notificationsEnabled': false,
    });
    expect(AuthService.instance.preferences['notificationsEnabled'], isFalse);
  });
}
