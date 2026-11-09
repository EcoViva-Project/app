import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/services/auth_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // A primeira tela aparece na hora; a sessão salva é conferida em seguida e o
  // roteador troca a tela de abertura pelo login ou pelo início.
  runApp(const EcoApp());
  AuthService.instance.initialize();
}
