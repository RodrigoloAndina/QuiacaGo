import 'package:flutter_test/flutter_test.dart';
import 'package:quiaca_go_conductor/services/driver_document_rules.dart';

void main() {
  group('DriverDocumentRules', () {
    test('detecta archivos inválidos o demasiado grandes', () {
      expect(
          DriverDocumentRules.validateUpload('documento.exe', 100), isNotNull);
      expect(DriverDocumentRules.validateUpload('documento.pdf', 0), isNotNull);
      expect(
          DriverDocumentRules.validateUpload(
              'documento.pdf', DriverDocumentRules.maxUploadBytes + 1),
          isNotNull);
      expect(
          DriverDocumentRules.validateUpload('documento.jpeg', 1024), isNull);
    });

    test('considera vigente un documento que vence hoy', () {
      final now = DateTime(2026, 10, 3, 22, 30);
      expect(
          DriverDocumentRules.daysUntilExpiry(DateTime(2026, 10, 3), now: now),
          0);
    });

    test('resume faltantes, vencidos, pendientes y rechazados', () {
      final summary = DriverDocumentRules.summarize([
        {'document_type': 'dni_front', 'status': 'approved'},
        {'document_type': 'dni_back', 'status': 'rejected'},
        {
          'document_type': 'license',
          'status': 'approved',
          'expires_at': '2026-10-02'
        },
        {
          'document_type': 'insurance',
          'status': 'pending',
          'expires_at': '2027-01-01'
        },
      ], now: DateTime(2026, 10, 3));

      expect(summary.missing, ['vtv']);
      expect(summary.rejected, ['dni_back']);
      expect(summary.expired, ['license']);
      expect(summary.pending, ['insurance']);
      expect(summary.canBeApproved, isFalse);
    });
  });
}
