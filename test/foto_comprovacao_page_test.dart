import 'package:eco_app/app/app.dart';
import 'package:eco_app/core/services/action_history_service.dart';
import 'package:eco_app/core/services/photo_picker.dart';
import 'package:eco_app/core/services/photo_proof.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_photos.dart';
import 'support/local_app.dart';

late FakePhotoPicker _picker;
late FakePhotoFileStore _files;

Future<void> _open(WidgetTester tester, String route) async {
  AppRouter.router.go(route);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.tap(target);
  await _settle(tester);
}

/// Abre o registro de "Apagar luzes em cômodos vazios" (ainda livre hoje na
/// conta de demonstração).
Future<void> _openRegister(WidgetTester tester) async {
  await signInDemo();
  await tester.pumpWidget(const EcoApp());
  await tester.pump();
  await _open(tester, '/registro-acao/5');
  expect(find.text('Confirmar registro'), findsOneWidget);
}

final Finder _preview = find.byKey(
  const ValueKey<String>('registro-foto-previa'),
);

void main() {
  setUp(() async {
    await useLocalBackend();
    _picker = FakePhotoPicker();
    _files = FakePhotoFileStore();
    PhotoProof.picker = _picker;
    PhotoProof.files = _files;
    PhotoProof.availableOverride = true;
  });

  tearDown(restorePhotoProof);

  testWidgets('foto: prévia, registro, selo na confirmação e no histórico', (
    tester,
  ) async {
    await _openRegister(tester);
    expect(find.text('Foto de comprovação (opcional)'), findsOneWidget);
    expect(
      find.textContaining(
        'A foto fica só neste celular e ainda não é conferida',
      ),
      findsOneWidget,
    );

    await _tap(tester, find.text('Tirar foto'));
    expect(_picker.calls, [PhotoSource.camera]);
    expect(_preview, findsOneWidget);
    expect(find.text('Remover foto'), findsOneWidget);
    expect(find.text('Tirar foto'), findsNothing);
    expect(_files.saved, isEmpty, reason: 'só copia ao registrar');

    await _tap(tester, find.text('Confirmar registro'));

    // Confirmação com a miniatura e o selo.
    expect(find.text('Ação registrada!'), findsOneWidget);
    expect(find.text('Com comprovação'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('confirmacao-foto')),
      findsOneWidget,
    );
    expect(_files.saved, ['foto_teste_1.jpg']);
    final record = ActionHistoryService.instance.lastSubmission!.record;
    expect(record.photo?.file, 'foto_teste_1.jpg');
    // Os pontos são os da ação, com ou sem foto.
    expect(find.text('+${record.points} pts'), findsWidgets);

    // Histórico: o registro novo é o primeiro e tem o selo.
    await _open(tester, '/meu-historico');
    final badges = find.text('Com comprovação');
    expect(badges, findsWidgets);
    await _tap(tester, badges.first);

    // Tela cheia com zoom; o arquivo falso não existe, então aparece o aviso.
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.text('Foto indisponível'), findsOneWidget);
    expect(find.text(record.title), findsWidgets);
    await _tap(tester, find.byTooltip('Fechar foto'));
    expect(find.byType(InteractiveViewer), findsNothing);
    expect(find.text('Meu histórico'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('remover a foto antes de registrar registra sem foto', (
    tester,
  ) async {
    await _openRegister(tester);
    await _tap(tester, find.text('Escolher da galeria'));
    expect(_picker.calls, [PhotoSource.gallery]);
    expect(_preview, findsOneWidget);

    await _tap(tester, find.text('Remover foto'));
    expect(_preview, findsNothing);
    expect(find.text('Tirar foto'), findsOneWidget);

    await _tap(tester, find.text('Confirmar registro'));
    expect(find.text('Ação registrada!'), findsOneWidget);
    expect(find.text('Com comprovação'), findsNothing);
    expect(_files.saved, isEmpty);
    expect(ActionHistoryService.instance.lastSubmission!.record.photo, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desistir da câmera não muda nada', (tester) async {
    await _openRegister(tester);
    _picker.next = null;
    await _tap(tester, find.text('Tirar foto'));
    expect(_picker.calls, [PhotoSource.camera]);
    expect(_preview, findsNothing);
    expect(find.text('Tirar foto'), findsOneWidget);
    expect(find.text('Escolher da galeria'), findsOneWidget);

    await _tap(tester, find.text('Confirmar registro'));
    expect(find.text('Ação registrada!'), findsOneWidget);
    expect(ActionHistoryService.instance.lastSubmission!.record.photo, isNull);
    expect(_files.saved, isEmpty);
  });

  testWidgets('foto recuperada depois de o Android fechar o app', (
    tester,
  ) async {
    _picker.lost = 'C:/fotos-de-teste/recuperada.jpg';
    await _openRegister(tester);
    await _settle(tester);
    expect(_preview, findsOneWidget);
    expect(
      find.text('Recuperamos a foto que você tinha tirado.'),
      findsOneWidget,
    );
  });

  testWidgets('fora do modo local, os botões de foto não aparecem', (
    tester,
  ) async {
    PhotoProof.availableOverride = false;
    _picker.lost = 'C:/fotos-de-teste/recuperada.jpg';
    await _openRegister(tester);
    expect(find.text('Foto de comprovação (opcional)'), findsNothing);
    expect(find.text('Tirar foto'), findsNothing);
    expect(find.text('Escolher da galeria'), findsNothing);
    expect(_preview, findsNothing);

    await _tap(tester, find.text('Confirmar registro'));
    expect(find.text('Ação registrada!'), findsOneWidget);
    expect(_picker.calls, isEmpty);
  });

  testWidgets('histórico da demonstração já mostra as fotos de exemplo', (
    tester,
  ) async {
    await signInDemo();
    await tester.pumpWidget(const EcoApp());
    await tester.pump();
    await _open(tester, '/meu-historico');
    final badges = find.text('Com comprovação', skipOffstage: false);
    expect(badges, findsWidgets);
    await _tap(tester, find.text('Com comprovação').first);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.text('Foto de exemplo da demonstração.'), findsOneWidget);
    expect(find.text('Foto indisponível'), findsNothing);
    await _tap(tester, find.byTooltip('Fechar foto'));
    expect(tester.takeException(), isNull);
  });
}
