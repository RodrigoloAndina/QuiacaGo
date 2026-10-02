import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'features/admin/admin_aprobaciones_screen.dart';
import 'services/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await SupabaseService().initialize();
  } catch (_) {}

  runApp(
    const ProviderScope(
      child: QuiacaGoAdminApp(),
    ),
  );
}

class QuiacaGoAdminApp extends StatelessWidget {
  const QuiacaGoAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QuiacaGo - Panel Administrador Municipal',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AdminAprobacionesScreen(),
    );
  }
}
