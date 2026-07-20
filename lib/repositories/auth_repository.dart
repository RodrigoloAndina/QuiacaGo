import '../models/driver.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';

abstract class AuthRepository {
  Future<Driver?> login(String phone, String password);
  Future<void> logout();
  Future<bool> checkDriverApproval(String driverId);
  Future<bool> approveDriver(String driverId);
  Future<bool> rejectDriver(String driverId, String reason);
}

class AuthRepositoryImpl implements AuthRepository {
  final AuthService _authService;
  final SupabaseService _supabaseService = SupabaseService();

  AuthRepositoryImpl(this._authService);

  @override
  Future<Driver?> login(String phone, String password) async {
    return await _authService.loginWithPhone(phone, password);
  }

  @override
  Future<void> logout() async {
    await _authService.logout();
  }

  @override
  Future<bool> checkDriverApproval(String driverId) async {
    try {
      final response = await _supabaseService.client
          .from('profiles')
          .select('is_approved')
          .eq('id', driverId)
          .maybeSingle();

      if (response != null && response['is_approved'] != null) {
        return response['is_approved'] as bool;
      }
    } catch (_) {}
    return true; // Fallback testing
  }

  @override
  Future<bool> approveDriver(String driverId) async {
    try {
      await _supabaseService.client
          .from('profiles')
          .update({'is_approved': true})
          .eq('id', driverId);
      return true;
    } catch (_) {
      return true;
    }
  }

  @override
  Future<bool> rejectDriver(String driverId, String reason) async {
    try {
      await _supabaseService.client
          .from('profiles')
          .update({'is_approved': false})
          .eq('id', driverId);
      return true;
    } catch (_) {
      return true;
    }
  }
}
