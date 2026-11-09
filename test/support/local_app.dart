import 'dart:math';

import 'package:eco_app/core/local/local_api.dart';
import 'package:eco_app/core/local/local_store.dart';
import 'package:eco_app/core/services/api_client.dart';
import 'package:eco_app/core/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Quarta-feira, 11/11/2026, 15:00 em Brasília.
final DateTime demoNow = DateTime.utc(2026, 11, 11, 18);

/// Relógio usado pela API local dos testes; pode ser avançado.
DateTime testClock = demoNow;

/// Prepara o app para um teste: API local em memória, com os dados de
/// demonstração, e nenhuma sessão salva.
///
/// Os testes passam pelas mesmas regras e pelos mesmos serviços do app de
/// verdade; nada de dados de exemplo embutidos no código de produção.
Future<LocalApi> useLocalBackend() async {
  SharedPreferences.setMockInitialValues({});
  testClock = demoNow;
  final api = LocalApi(
    LocalDatabase(MemoryStore()),
    clock: () => testClock,
    random: Random(7),
  );
  ApiClient.instance.useTransport(LocalTransport(api));
  await AuthService.instance.logout();
  await AuthService.instance.initialize();
  return api;
}

/// Entra com a conta de demonstração e carrega todos os serviços.
Future<void> signInDemo() => AuthService.instance.login(
  email: AuthService.demoEmail,
  password: AuthService.demoPassword,
);
