import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'features/pasajero/inicio_pasajero_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: QuiacaGoPasajeroApp(),
    ),
  );
}

class QuiacaGoPasajeroApp extends StatelessWidget {
  const QuiacaGoPasajeroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QuiacaGo Pasajero',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const InicioPasajeroScreen(),
    );
  }
}
