import 'package:flutter_test/flutter_test.dart';
import 'package:quiaca_go_conductor/services/app_release_service.dart';

void main() {
  group('AppReleaseDecision', () {
    test('interpreta una versión habilitada', () {
      final decision = AppReleaseDecision.fromRpc({
        'allowed': true,
        'reason': 'allowed',
        'message': 'Versión habilitada',
        'server_time': '2026-10-04T12:00:00Z',
      });

      expect(decision.allowed, isTrue);
      expect(decision.reason, 'allowed');
      expect(decision.serverTime, DateTime.utc(2026, 10, 4, 12));
    });

    test('interpreta vencimiento y enlace de actualización', () {
      final decision = AppReleaseDecision.fromRpc({
        'allowed': false,
        'reason': 'expired',
        'message': 'La prueba terminó.',
        'expires_at': '2026-10-31T23:59:00Z',
        'update_url': 'https://quiacago.example/actualizar',
      });

      expect(decision.allowed, isFalse);
      expect(decision.reason, 'expired');
      expect(decision.expiresAt, isNotNull);
      expect(decision.updateUrl, 'https://quiacago.example/actualizar');
    });
  });
}
