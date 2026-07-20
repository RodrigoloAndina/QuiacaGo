import '../models/driver.dart';
import '../core/constants/app_constants.dart';

class AuthService {
  // Simulación y cliente de autenticación
  Future<Driver?> loginWithPhone(String phone, String password) async {
    await Future.delayed(const Duration(milliseconds: 600));

    // Retorna conductor activo para pruebas
    return Driver(
      id: 'driver-042',
      nombre: 'Carlos Mamani',
      telefono: phone,
      estado: DriverStatus.OFFLINE,
      calificacion: 4.95,
    );
  }

  Future<void> logout() async {
    await Future.delayed(const Duration(milliseconds: 300));
  }
}
