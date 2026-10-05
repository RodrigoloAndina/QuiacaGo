import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../services/auth_service.dart';
import '../legal/legal_screen.dart';

class CuentaPendienteScreen extends StatefulWidget {
  const CuentaPendienteScreen({super.key, this.motivoInhabilitacion});
  final String? motivoInhabilitacion;
  @override
  State<CuentaPendienteScreen> createState() => _CuentaPendienteScreenState();
}
class _CuentaPendienteScreenState extends State<CuentaPendienteScreen> {
  bool _checking = false;
  String? _message;
  Future<void> _refresh() async {
    setState(() => _checking = true);
    try {
      final enabled = await AuthService().refreshDriverCompliance();
      if (!mounted) return;
      if (enabled) { context.go('/home'); return; }
      setState(() => _message = 'Tu cuenta todavía necesita revisión. Consultá los estados y observaciones de cada documento.');
    } catch (_) { if (mounted) setState(() => _message = 'No pudimos actualizar el estado. Revisá tu conexión y reintentá.'); }
    finally { if (mounted) setState(() => _checking = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Habilitación del conductor')),
    body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: ListView(padding: const EdgeInsets.all(24), children: [
      const Icon(Icons.fact_check_outlined, size: 72, color: AppColors.primary), const SizedBox(height: 20),
      Text(widget.motivoInhabilitacion ?? 'Tu cuenta necesita revisión', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall), const SizedBox(height: 12),
      const Text('Podés cargar o reemplazar tus documentos y consultar las observaciones. Para recibir viajes, administración debe aprobar el legajo y la documentación debe estar vigente.', textAlign: TextAlign.center), const SizedBox(height: 24),
      FilledButton.icon(onPressed: () => context.push('/documentacion'), icon: const Icon(Icons.upload_file), label: const Text('REVISAR MI DOCUMENTACIÓN')), const SizedBox(height: 12),
      OutlinedButton.icon(onPressed: _checking ? null : _refresh, icon: const Icon(Icons.refresh), label: Text(_checking ? 'CONSULTANDO…' : 'ACTUALIZAR ESTADO')),
      if (_message != null) Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Text(_message!, textAlign: TextAlign.center)), const SizedBox(height: 20),
      ListTile(leading: const Icon(Icons.support_agent), title: const Text('Contactar a soporte'), trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/soporte')),
      ListTile(leading: const Icon(Icons.manage_accounts_outlined), title: const Text('Mi perfil y eliminación de cuenta'), trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/perfil')),
      ListTile(leading: const Icon(Icons.policy_outlined), title: const Text('Condiciones y privacidad'), onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const LegalScreen()))),
      TextButton.icon(onPressed: () async { await AuthService().logout(); if (context.mounted) context.go('/login'); }, icon: const Icon(Icons.logout), label: const Text('CERRAR SESIÓN')),
    ]))),
  );
}
