import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/driver.dart';
import '../services/auth_service.dart';
import '../repositories/auth_repository.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(ref.watch(authServiceProvider));
});

class AuthState {
  final Driver? driver;
  final bool isLoading;
  final String? errorMessage;

  AuthState({
    this.driver,
    this.isLoading = false,
    this.errorMessage,
  });

  bool get isAuthenticated => driver != null;
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;

  AuthNotifier(this._repository) : super(AuthState());

  Future<bool> login(String phone, String password) async {
    state = AuthState(isLoading: true);
    try {
      final driver = await _repository.login(phone, password);
      if (driver != null) {
        state = AuthState(driver: driver);
        return true;
      } else {
        state = AuthState(errorMessage: 'Credenciales inválidas');
        return false;
      }
    } catch (e) {
      state = AuthState(errorMessage: e.toString());
      return false;
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    state = AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});
