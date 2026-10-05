import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'driver_tracking_service.dart';
import 'driver_session_service.dart';
import 'passenger_background_service.dart';
import 'offline_sync_service.dart';
import 'current_trip_session.dart';

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

  Future<bool> refreshDriverCompliance() async {
    final id = _client.auth.currentUser?.id;
    if (id == null) return false;
    final result = await _client.rpc('refresh_driver_compliance', params: {
      'p_driver_id': id,
      'p_notify': true,
    });
    return result == true;
  }

  Future<Map<String, dynamic>> updateDriverProfile({
    required String fullName,
    required String phone,
    required String vehicleInfo,
    required String plate,
    required String taxiNumber,
  }) async {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('La sesión venció. Volvé a ingresar.');
    final rows = await _client
        .from('profiles')
        .update({
          'full_name': fullName.trim(),
          'phone': phone.trim(),
          'vehicle_info': vehicleInfo.trim(),
          'plate': plate.trim().toUpperCase(),
          'taxi_number': taxiNumber.trim(),
        })
        .eq('id', id)
        .eq('role', 'driver')
        .select();
    if (rows.isEmpty) {
      throw StateError('No se encontró el perfil del conductor.');
    }
    return Map<String, dynamic>.from(rows.first);
  }

  Future<void> logout() async {
    // El cierre local debe completarse aun si una red o un plugin falla.
    try {
      await DriverTrackingService().stop();
    } catch (_) {}
    try {
      await PassengerBackgroundService.stop();
    } catch (_) {}
    CurrentTripSession().clear();
    try {
      await OfflineSyncService().clearUserData();
    } catch (_) {}
    DriverSessionService().clear();
    await _client.auth.signOut(scope: SignOutScope.local);
  }
}
