import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'supabase_service.dart';

class SupportConfig {
  final String supportPhone;
  final String emergencyPhone;

  const SupportConfig({
    required this.supportPhone,
    required this.emergencyPhone,
  });
}

class SupportService {
  SupabaseClient get _client => SupabaseService().client;

  Future<SupportConfig> load() async {
    try {
      final value = await _client.rpc('get_public_support_config');
      final map = Map<String, dynamic>.from(value as Map);
      return SupportConfig(
        supportPhone: map['support_phone']?.toString() ?? '',
        emergencyPhone: map['emergency_phone']?.toString() ?? '911',
      );
    } catch (_) {
      return const SupportConfig(supportPhone: '', emergencyPhone: '911');
    }
  }

  Future<bool> call(String phone) =>
      launchUrl(Uri(scheme: 'tel', path: _phoneForUri(phone)));

  Future<bool> openWhatsApp(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    return launchUrl(
      Uri.parse(
          'https://wa.me/$digits?text=${Uri.encodeComponent('Hola, necesito ayuda con QuiacaGo.')}'),
      mode: LaunchMode.externalApplication,
    );
  }

  String _phoneForUri(String value) => value.replaceAll(RegExp(r'[^0-9+]'), '');
}
