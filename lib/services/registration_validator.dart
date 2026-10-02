class RegistrationValidator {
  static final RegExp _emailPattern = RegExp(
    r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+$",
  );

  static String digitsOnly(String value) =>
      value.replaceAll(RegExp(r'[^0-9]'), '');

  static String? requiredText(String? value, String label) {
    if (value == null || value.trim().isEmpty) return '$label es obligatorio';
    return null;
  }

  static String? email(String? value) {
    final normalized = value?.trim() ?? '';
    if (!_emailPattern.hasMatch(normalized)) return 'Ingresá un correo válido';
    return null;
  }

  static String? phone(String? value) {
    final digits = digitsOnly(value ?? '');
    if (digits.length < 10 || digits.length > 15) {
      return 'Ingresá un teléfono válido con código de área';
    }
    return null;
  }

  static String? dni(String? value) {
    final digits = digitsOnly(value ?? '');
    if (digits.length < 7 || digits.length > 8) return 'Ingresá un DNI válido';
    return null;
  }

  static String? password(String? value) {
    final password = value ?? '';
    if (password.length < 8) return 'Usá al menos 8 caracteres';
    if (!RegExp(r'[A-Za-z]').hasMatch(password) ||
        !RegExp(r'[0-9]').hasMatch(password)) {
      return 'Incluí al menos una letra y un número';
    }
    return null;
  }

  static String? passwordConfirmation(String? value, String password) {
    if (value != password) return 'Las contraseñas no coinciden';
    return null;
  }

  static String? plate(String? value) {
    final plate = (value ?? '').replaceAll(RegExp(r'[\s-]'), '').toUpperCase();
    if (!RegExp(r'^(?:[A-Z]{3}[0-9]{3}|[A-Z]{2}[0-9]{3}[A-Z]{2})$')
        .hasMatch(plate)) {
      return 'Formato esperado: ABC 123 o AB 123 CD';
    }
    return null;
  }
}
