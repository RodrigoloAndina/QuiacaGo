import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

class AppReleaseDecision {
  final bool allowed;
  final String reason;
  final String message;
  final String? updateUrl;
  final DateTime? expiresAt;
  final DateTime? serverTime;

  const AppReleaseDecision({
    required this.allowed,
    required this.reason,
    required this.message,
    this.updateUrl,
    this.expiresAt,
    this.serverTime,
  });

  factory AppReleaseDecision.fromRpc(dynamic value) {
    final data = Map<String, dynamic>.from(value as Map);
    return AppReleaseDecision(
      allowed: data['allowed'] == true,
      reason: data['reason']?.toString() ?? 'unknown',
      message: data['message']?.toString().trim().isNotEmpty == true
          ? data['message'].toString().trim()
          : 'Esta versión ya no está disponible.',
      updateUrl: data['update_url']?.toString().trim().isNotEmpty == true
          ? data['update_url'].toString().trim()
          : null,
      expiresAt: DateTime.tryParse(data['expires_at']?.toString() ?? ''),
      serverTime: DateTime.tryParse(data['server_time']?.toString() ?? ''),
    );
  }
}

class AppReleaseService {
  SupabaseClient get _client => SupabaseService().client;

  Future<AppReleaseDecision> check() async {
    final configuration = SupabaseService();
    try {
      final response = await _client.rpc('check_app_release', params: {
        'p_app_key': configuration.appKey,
        'p_build_number': configuration.buildNumber,
      });
      return AppReleaseDecision.fromRpc(response);
    } catch (_) {
      if (configuration.isBeta) {
        return const AppReleaseDecision(
          allowed: false,
          reason: 'verification_unavailable',
          message:
              'No pudimos verificar esta versión de prueba. Conectate a internet e intentá nuevamente.',
        );
      }
      return const AppReleaseDecision(
        allowed: true,
        reason: 'production_fallback',
        message: '',
      );
    }
  }
}
