import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'features/splash/splash_pasajero_screen.dart';
import 'features/pasajero/login_pasajero_screen.dart';
import 'features/pasajero/registro_pasajero_screen.dart';
import 'features/pasajero/inicio_pasajero_screen.dart';
import 'services/supabase_service.dart';
import 'services/offline_sync_service.dart';
import 'features/release/app_release_gate.dart';
import 'features/profile/cuenta_pasajero_screen.dart';
import 'features/support/support_screen.dart';
import 'features/legal/legal_gate.dart';

final GoRouter pasajeroRouter = GoRouter(
  initialLocation: '/splash-pasajero',
  routes: <RouteBase>[
    GoRoute(
      path: '/splash-pasajero',
      builder: (BuildContext context, GoRouterState state) =>
          const SplashPasajeroScreen(),
    ),
    GoRoute(
      path: '/login-pasajero',
      builder: (BuildContext context, GoRouterState state) =>
          const LoginPasajeroScreen(),
    ),
    GoRoute(
      path: '/registro-pasajero',
      builder: (BuildContext context, GoRouterState state) =>
          const RegistroPasajeroScreen(),
    ),
    GoRoute(
      path: '/pasajero-home',
      builder: (BuildContext context, GoRouterState state) =>
          const LegalGate(child: InicioPasajeroScreen()),
    ),
    GoRoute(
      path: '/cuenta-pasajero',
      builder: (BuildContext context, GoRouterState state) =>
          const CuentaPasajeroScreen(),
    ),
    GoRoute(
      path: '/soporte-pasajero',
      builder: (BuildContext context, GoRouterState state) =>
          const SupportScreen(),
    ),
  ],
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicialización oficial de Supabase Realtime para la App de Pasajeros
  try {
    await SupabaseService().initialize(appType: 'pasajero');
    await OfflineSyncService().start();
  } catch (_) {}

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
    return MaterialApp.router(
      title: 'QuiacaGo Pasajero',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: pasajeroRouter,
      builder: (context, child) => ConnectionStatusOverlay(
        child: AppReleaseGate(child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}
