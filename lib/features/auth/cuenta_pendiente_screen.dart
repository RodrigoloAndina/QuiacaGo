import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';

class CuentaPendienteScreen extends StatelessWidget {
  final String? motivoInhabilitacion;
  final String adminPhone;

  const CuentaPendienteScreen({
    super.key,
    this.motivoInhabilitacion = 'Falta de pago de cuota mensual municipal',
    this.adminPhone = '+54 9 388 540-1234',
  });

  Future<void> _abrirWhatsApp() async {
    final url = Uri.parse('https://wa.me/5493885401234?text=Hola,%20necesito%20regularizar%20mi%20cuenta%20de%20QuiacaGo');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final motivo = motivoInhabilitacion ?? 'Falta de pago de cuota mensual municipal';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              Container(
                width: 84,
                height: 84,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFEBEB),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.block_rounded, size: 48, color: Color(0xFFD32F2F)),
              ),
              const SizedBox(height: 20),
              const Text(
                'ACCESO RESTRINGIDO',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFD32F2F),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'QuiacaGo Conductor',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.outline,
                ),
              ),
              const SizedBox(height: 20),

              // Caja destacada de Motivo
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFFCDD2), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.04),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'MOTIVO REGISTRADO EN SISTEMA:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.outline,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      motivo,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFD32F2F),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text(
                      'Comunícate con un Administrador para regularizar tu cuota mensual o subir la documentación actualizada.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12.5, color: AppColors.onSurfaceVariant, height: 1.4),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Botón WhatsApp
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _abrirWhatsApp,
                  icon: const Icon(Icons.chat, color: Colors.white),
                  label: const Text(
                    'CONTACTAR ADMINISTRADOR (WHATSAPP)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366), // Verde WhatsApp
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Botón Subir Papeles / Comprobante
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/documentacion'),
                  icon: const Icon(Icons.cloud_upload_outlined, color: AppColors.primary),
                  label: const Text(
                    'SUBIR PAPELES Y COMPROBANTE',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              TextButton(
                onPressed: () => context.go('/login'),
                child: const Text(
                  'Volver al inicio de sesión',
                  style: TextStyle(color: AppColors.outline, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
