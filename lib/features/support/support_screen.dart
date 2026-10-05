import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../services/support_service.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  SupportConfig? _config;

  @override
  void initState() {
    super.initState();
    SupportService().load().then((value) {
      if (mounted) setState(() => _config = value);
    });
  }

  Future<void> _run(Future<bool> Function() action) async {
    final opened = await action();
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No se pudo abrir esta opción en el teléfono.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = _config;
    return Scaffold(
      appBar: AppBar(title: const Text('Ayuda y emergencia')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            color: const Color(0xFFFFF1F2),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.emergency_outlined,
                        color: AppColors.statusCancelled, size: 38),
                    const SizedBox(height: 10),
                    const Text('Emergencia inmediata',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    const Text(
                        'Si hay peligro, un accidente o una urgencia médica, llamá primero al servicio de emergencias.'),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                            backgroundColor: AppColors.statusCancelled),
                        onPressed: config == null
                            ? null
                            : () => _run(() =>
                                SupportService().call(config.emergencyPhone)),
                        icon: const Icon(Icons.call),
                        label: Text(
                            'LLAMAR AL ${config?.emergencyPhone ?? '...'}'),
                      ),
                    ),
                  ]),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.support_agent,
                        color: AppColors.primary, size: 38),
                    const SizedBox(height: 10),
                    const Text('Soporte QuiacaGo',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text(config?.supportPhone.isNotEmpty == true
                        ? 'Contactanos al ${config!.supportPhone} para problemas con tu cuenta o un viaje.'
                        : 'El número de soporte todavía no fue configurado. En una emergencia usá el botón superior.'),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: config?.supportPhone.isNotEmpty == true
                              ? () => _run(() =>
                                  SupportService().call(config!.supportPhone))
                              : null,
                          icon: const Icon(Icons.call_outlined),
                          label: const Text('LLAMAR'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: config?.supportPhone.isNotEmpty == true
                              ? () => _run(() => SupportService()
                                  .openWhatsApp(config!.supportPhone))
                              : null,
                          icon: const Icon(Icons.chat_outlined),
                          label: const Text('WHATSAPP'),
                        ),
                      ),
                    ]),
                  ]),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Compartí el identificador del viaje y describí lo ocurrido. No envíes contraseñas, códigos PIN ni datos bancarios.',
            style: TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }
}
