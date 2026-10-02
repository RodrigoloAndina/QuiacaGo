import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../services/driver_session_service.dart';
import '../../services/supabase_service.dart';

class VerificarTelefonoScreen extends StatefulWidget {
  const VerificarTelefonoScreen({super.key});

  @override
  State<VerificarTelefonoScreen> createState() =>
      _VerificarTelefonoScreenState();
}

class _VerificarTelefonoScreenState extends State<VerificarTelefonoScreen> {
  late final TextEditingController _phoneController;
  final _codeController = TextEditingController();
  bool _sending = false;
  bool _sent = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final raw = DriverSessionService().phone;
    _phoneController = TextEditingController(text: _argentinaPhone(raw));
  }

  String _argentinaPhone(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('54')) return '+$digits';
    if (digits.length == 10) return '+549$digits';
    return digits.isEmpty ? '' : '+$digits';
  }

  Future<void> _sendCode() async {
    final phone = _argentinaPhone(_phoneController.text);
    if (phone.length < 12) {
      setState(() => _error = 'Ingresá un celular argentino válido.');
      return;
    }
    setState(() { _sending = true; _error = null; });
    try {
      await SupabaseService().client.auth.updateUser(UserAttributes(phone: phone));
      if (mounted) setState(() => _sent = true);
    } catch (error) {
      if (mounted) setState(() => _error =
          'No se pudo enviar el código. Verificá que el proveedor SMS esté configurado en Supabase.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _verify() async {
    final phone = _argentinaPhone(_phoneController.text);
    final token = _codeController.text.trim();
    if (token.length != 6) {
      setState(() => _error = 'Ingresá el código de 6 dígitos.');
      return;
    }
    setState(() { _sending = true; _error = null; });
    try {
      await SupabaseService().client.auth.verifyOTP(
            type: OtpType.phoneChange, phone: phone, token: token);
      await SupabaseService().client.rpc('confirm_my_phone_verification',
          params: {'p_phone': phone});
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = 'Código incorrecto o vencido.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() { _phoneController.dispose(); _codeController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Verificar teléfono')),
        body: ListView(padding: const EdgeInsets.all(22), children: [
          const Icon(Icons.verified_user_outlined, size: 64, color: AppColors.primary),
          const SizedBox(height: 16),
          const Text('Confirmá que este celular es tuyo', textAlign: TextAlign.center,
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text('Te enviaremos un código de 6 dígitos por SMS. El número verificado se usará para avisos de la Municipalidad.',
              textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 24),
          TextField(controller: _phoneController, keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Celular', hintText: '+54 9 3885 000000')),
          const SizedBox(height: 14),
          if (_sent) TextField(controller: _codeController, keyboardType: TextInputType.number,
              maxLength: 6, decoration: const InputDecoration(labelText: 'Código recibido')),
          if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 12),
              child: Text(_error!, style: const TextStyle(color: AppColors.statusRejected))),
          SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: _sending ? null : (_sent ? _verify : _sendCode),
              child: Text(_sending ? 'PROCESANDO...' : (_sent ? 'CONFIRMAR CÓDIGO' : 'ENVIAR CÓDIGO')))),
        ]),
      );
}
