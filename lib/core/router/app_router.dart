import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/splash/splash_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/recuperar_password_screen.dart';
import '../../features/auth/cuenta_pendiente_screen.dart';
import '../../features/admin/admin_aprobaciones_screen.dart';
import '../../features/home/inicio_conductor_screen.dart';
import '../../features/trips/nuevo_pedido_modal.dart';
import '../../features/trips/taxi_asignado_screen.dart';
import '../../features/trips/confirmacion_llegada_screen.dart';
import '../../features/trips/codigo_seguridad_screen.dart';
import '../../features/trips/viaje_en_curso_screen.dart';
import '../../features/trips/finalizacion_viaje_screen.dart';
import '../../features/earnings/mis_ganancias_screen.dart';
import '../../features/trips/historial_viajes_screen.dart';
import '../../features/profile/perfil_usuario_screen.dart';
import '../../features/documents/documentacion_conductor_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/splash',
  routes: <RouteBase>[
    GoRoute(
      path: '/splash',
      builder: (BuildContext context, GoRouterState state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (BuildContext context, GoRouterState state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/recuperar-password',
      builder: (BuildContext context, GoRouterState state) => const RecuperarPasswordScreen(),
    ),
    GoRoute(
      path: '/cuenta-pendiente',
      builder: (BuildContext context, GoRouterState state) => const CuentaPendienteScreen(),
    ),
    GoRoute(
      path: '/admin-aprobaciones',
      builder: (BuildContext context, GoRouterState state) => const AdminAprobacionesScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (BuildContext context, GoRouterState state) => const InicioConductorScreen(),
    ),
    GoRoute(
      path: '/nuevo-pedido',
      builder: (BuildContext context, GoRouterState state) => const NuevoPedidoModal(),
    ),
    GoRoute(
      path: '/taxi-asignado',
      builder: (BuildContext context, GoRouterState state) => const TaxiAsignadoScreen(),
    ),
    GoRoute(
      path: '/confirmacion-llegada',
      builder: (BuildContext context, GoRouterState state) => const ConfirmacionLlegadaScreen(),
    ),
    GoRoute(
      path: '/codigo-seguridad',
      builder: (BuildContext context, GoRouterState state) => const CodigoSeguridadScreen(),
    ),
    GoRoute(
      path: '/viaje-en-curso',
      builder: (BuildContext context, GoRouterState state) => const ViajeEnCursoScreen(),
    ),
    GoRoute(
      path: '/finalizacion-viaje',
      builder: (BuildContext context, GoRouterState state) => const FinalizacionViajeScreen(),
    ),
    GoRoute(
      path: '/ganancias',
      builder: (BuildContext context, GoRouterState state) => const MisGananciasScreen(),
    ),
    GoRoute(
      path: '/historial',
      builder: (BuildContext context, GoRouterState state) => const HistorialViajesScreen(),
    ),
    GoRoute(
      path: '/perfil',
      builder: (BuildContext context, GoRouterState state) => const PerfilUsuarioScreen(),
    ),
    GoRoute(
      path: '/documentacion',
      builder: (BuildContext context, GoRouterState state) => const DocumentacionConductorScreen(),
    ),
  ],
);
