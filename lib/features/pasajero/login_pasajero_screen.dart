import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../services/supabase_service.dart';

class LoginPasajeroScreen extends StatefulWidget {
  const LoginPasajeroScreen({super.key});

  @override
  State<LoginPasajeroScreen> createState() => _LoginPasajeroScreenState();
}

class _LoginPasajeroScreenState extends State<LoginPasajeroScreen> {
  final _telefonoDniCtrl = TextEditingController(text: '38450123');
  final _passwordCtrl = TextEditingController(text: '123456');
  bool _isLoading = false;

  Future<void> _ingresarPasajero() async {
    setState(() => _isLoading = true);

    try {
      final input = _telefonoDniCtrl.text.trim();
      final supabase = SupabaseService().client;

      // Buscar perfil en Supabase
      final data = await supabase
          .from('profiles')
          .select()
          .or('phone.eq.$input,email.eq.$input')
          .maybeSingle();

      if (mounted) {
        setState(() => _isLoading = false);
        context.go('/pasajero-home');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
        context.go('/pasajero-home');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 30),
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.hail, size: 40, color: Colors.white),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'QuiacaGo Pasajero',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                    ),
                    const Text(
                      'Solicita Taxis Habilitados en La Quiaca',
                      style: TextStyle(fontSize: 13, color: AppColors.outline),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ACCESO PASAJEROS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF10B981),
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _telefonoDniCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Teléfono Celular o DNI',
                        prefixIcon: const Icon(Icons.phone_android, color: Color(0xFF10B981)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Contraseña de Pasajero',
                        prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF10B981)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _ingresarPasajero,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                                'INGRESAR A QUIACAGO PASAJERO',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),

                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: () => context.push('/registro-pasajero'),
                        icon: const Icon(Icons.person_add, color: Color(0xFF10B981)),
                        label: const Text(
                          '¿Nuevo Pasajero? Registrate aquí',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF10B981)),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF10B981), width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
