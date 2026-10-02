import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class AuthService {
  SupabaseClient get _client => SupabaseService().client;
  bool get hasSession => _client.auth.currentSession != null;

  static String? suspensionMessage(Map<String, dynamic>? profile) {
    final until = DateTime.tryParse(
        profile?['account_suspended_until']?.toString() ?? '');
    if (until == null || !until.isAfter(DateTime.now().toUtc())) return null;
    final reason = profile?['account_suspension_reason']?.toString().trim();
    final localUntil = until.toLocal();
    final date =
        '${localUntil.day.toString().padLeft(2, '0')}/${localUntil.month.toString().padLeft(2, '0')}/${localUntil.year}';
    return 'Cuenta suspendida hasta el $date.${reason?.isNotEmpty == true ? ' Motivo: $reason' : ''}';
  }

  static String emailForPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    return '$digits@usuarios.quiacago.app';
  }

  Future<AuthResponse> signIn(
      {required String identifier, required String password}) {
    final email = identifier.contains('@')
        ? identifier.trim()
        : emailForPhone(identifier);
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<AuthResponse> signUp(
          {required String email,
          required String password,
          required String fullName,
          required String phone,
          required String role,
          Map<String, dynamic>? extraData}) =>
      _client.auth
          .signUp(email: email.trim().toLowerCase(), password: password, data: {
        'full_name': fullName,
        'phone': phone,
        'role': role,
        ...?extraData,
      });

  Future<void> resendSignupConfirmation(String email) =>
      _client.auth.resend(type: OtpType.signup, email: email.trim());

  Future<Map<String, dynamic>?> currentProfile() async {
    final id = _client.auth.currentUser?.id;
    if (id == null) return null;
    return _client.from('profiles').select().eq('id', id).maybeSingle();
  }

  Future<void> logout() => _client.auth.signOut();
}
