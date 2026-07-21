import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/constants/app_constants.dart';
import 'services/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicialización oficial de Supabase Realtime para recepción instantánea de viajes
  try {
    await SupabaseService().initialize();
  } catch (_) {}

  runApp(
    const ProviderScope(
      child: QuiacaGoConductorApp(),
    ),
  );
}

class QuiacaGoConductorApp extends StatelessWidget {
  const QuiacaGoConductorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: appRouter,
    );
  }
}
