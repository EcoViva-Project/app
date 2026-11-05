import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/services/auth_service.dart';
import 'core/services/session_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SessionService.instance.load();
  await AuthService.instance.initialize();
  runApp(const EcoApp());
}
