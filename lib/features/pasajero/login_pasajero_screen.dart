import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../services/auth_service.dart';
import 'inicio_pasajero_screen.dart';
import '../legal/legal_screen.dart';

class LoginPasajeroScreen extends StatefulWidget {
  const LoginPasajeroScreen({super.key});

  @override
  State<LoginPasajeroScreen> createState() => _LoginPasajeroScreenState();
}

class _LoginPasajeroScreenState extends State<LoginPasajeroScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isLoading = false;
  String? _errorMsg;
  bool _emailNotConfirmed = false;

  Future<void> _ingresarPasajero() async {
    final input = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (input.isEmpty || !input.contains('@') || password.isEmpty) {
      setState(() => _errorMsg = 'Ingrese correo y contraseña');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMsg = null;
      _emailNotConfirmed = false;
    });

    try {
      final auth = AuthService();
      await auth.signIn(identifier: input, password: password);
      final data = await auth.currentProfile();

      if (data != null) {
        if (data['role'] != 'passenger') {
          await auth.logout();
          if (mounted) {
            setState(() {
              _isLoading = false;
              _errorMsg = 'Esta cuenta no pertenece a un pasajero';
            });
          }
          return;
        }
        final suspension = AuthService.suspensionMessage(data);
        if (suspension != null) {
          await auth.logout();
          if (mounted) {
            setState(() {
              _isLoading = false;
              _errorMsg = suspension;
            });
          }
          return;
        }
        InicioPasajeroScreen.passengerName =
            data['full_name']?.toString() ?? 'Pasajero';
        InicioPasajeroScreen.passengerPhone =
            data['phone']?.toString() ?? input;
      } else {
        throw StateError('Perfil de pasajero inexistente');
      }

      if (mounted) {
        setState(() => _isLoading = false);
        context.go('/pasajero-home');
      }
    } on AuthException catch (e) {
      if (mounted) {
        final unconfirmed = e.code == 'email_not_confirmed' ||
            e.message.toLowerCase().contains('not confirmed');
        setState(() {
          _isLoading = false;
          _emailNotConfirmed = unconfirmed;
          _errorMsg = unconfirmed
              ? 'Primero verificá tu correo desde el enlace que te enviamos.'
              : 'Correo o contraseña incorrectos.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMsg = 'No se pudo conectar. Intentá nuevamente.';
        });
      }
    }
  }

  Future<void> _reenviarConfirmacion() async {
    try {
      await AuthService().resendSignupConfirmation(_emailCtrl.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Correo de verificación reenviado. Revisá también Spam.'),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo reenviar: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
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
                      child:
                          const Icon(Icons.hail, size: 40, color: Colors.white),
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
                      color: Colors.black.withValues(alpha: 0.04),
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
                    if (_errorMsg != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: Color(0xFFEF4444), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(_errorMsg!,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFFEF4444),
                                        fontWeight: FontWeight.w600))),
                          ],
                        ),
                      ),
                      if (_emailNotConfirmed)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _reenviarConfirmacion,
                            child: const Text('REENVIAR VERIFICACIÓN'),
                          ),
                        ),
                    ],
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textCapitalization: TextCapitalization.none,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: 'Correo electrónico',
                        prefixIcon: const Icon(Icons.email_outlined,
                            color: Color(0xFF10B981)),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Contraseña de Pasajero',
                        prefixIcon: const Icon(Icons.lock_outline,
                            color: Color(0xFF10B981)),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => context.push('/recuperar-password'), child: const Text('Olvidé mi contraseña'))),
                    TextButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const LegalScreen())), icon: const Icon(Icons.policy_outlined), label: const Text('Condiciones y privacidad')),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _ingresarPasajero,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(40)),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text(
                                'INGRESAR A QUIACAGO PASAJERO',
                                style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.bold),
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
                        icon: const Icon(Icons.person_add,
                            color: Color(0xFF10B981)),
                        label: const Text(
                          '¿Nuevo Pasajero? Registrate aquí',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Color(0xFF10B981)),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: Color(0xFF10B981), width: 1.5),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(40)),
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
