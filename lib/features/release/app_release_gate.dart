import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../services/app_release_service.dart';
import '../../services/supabase_service.dart';

class AppReleaseGate extends StatefulWidget {
  final Widget child;

  const AppReleaseGate({super.key, required this.child});

  @override
  State<AppReleaseGate> createState() => _AppReleaseGateState();
}

class _AppReleaseGateState extends State<AppReleaseGate>
    with WidgetsBindingObserver {
  final _service = AppReleaseService();
  AppReleaseDecision? _decision;
  bool _checking = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
    _timer = Timer.periodic(const Duration(minutes: 5), (_) => _check());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    if (_decision == null && mounted) setState(() => _checking = true);
    final decision = await _service.check();
    if (!mounted) return;
    setState(() {
      _decision = decision;
      _checking = false;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_checking && _decision == null) return const _CheckingReleaseScreen();
    if (_decision?.allowed == true) return widget.child;
    return _BlockedReleaseScreen(decision: _decision!, onRetry: _check);
  }
}

class _CheckingReleaseScreen extends StatelessWidget {
  const _CheckingReleaseScreen();

  @override
  Widget build(BuildContext context) => const Material(
        color: AppColors.backgroundLight,
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.local_taxi, size: 58, color: AppColors.primary),
            SizedBox(height: 18),
            CircularProgressIndicator(),
            SizedBox(height: 14),
            Text('Verificando la versión de QuiacaGo…'),
          ]),
        ),
      );
}

class _BlockedReleaseScreen extends StatelessWidget {
  final AppReleaseDecision decision;
  final Future<void> Function() onRetry;

  const _BlockedReleaseScreen({required this.decision, required this.onRetry});

  Future<void> _openUpdate(BuildContext context) async {
    final value = decision.updateUrl;
    if (value == null) return;
    try {
      final opened = await launchUrl(Uri.parse(value),
          mode: LaunchMode.externalApplication);
      if (opened) return;
    } catch (_) {
      // El mensaje inferior permite solicitar el APK por otro medio.
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No se pudo abrir el enlace de actualización.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConnectionProblem = decision.reason == 'verification_unavailable';
    return Material(
      color: AppColors.backgroundLight,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(26),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                      isConnectionProblem
                          ? Icons.cloud_off_outlined
                          : Icons.system_update_alt,
                      size: 58,
                      color: isConnectionProblem
                          ? AppColors.statusPending
                          : AppColors.primary,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      isConnectionProblem
                          ? 'No se pudo verificar la prueba'
                          : 'Esta versión dejó de estar disponible',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 21, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    Text(decision.message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: AppColors.textSecondary, height: 1.4)),
                    const SizedBox(height: 20),
                    if (decision.updateUrl != null)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => _openUpdate(context),
                          icon: const Icon(Icons.download_outlined),
                          label: const Text('OBTENER VERSIÓN ACTUAL'),
                        ),
                      ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh),
                        label: const Text('VOLVER A COMPROBAR'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${SupabaseService().appKey} · compilación ${SupabaseService().buildNumber}',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
