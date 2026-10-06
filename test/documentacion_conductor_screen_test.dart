import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiaca_go_conductor/core/theme/app_theme.dart';
import 'package:quiaca_go_conductor/features/documents/documentacion_conductor_screen.dart';
import 'package:quiaca_go_conductor/services/driver_document_service.dart';

class _FakeDriverDocumentService extends DriverDocumentService {
  @override
  Future<List<Map<String, dynamic>>> forDriver(String driverId) async => [];
}

void main() {
  testWidgets('muestra el legajo y sus acciones sin errores de layout',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: DocumentacionConductorScreen(
          service: _FakeDriverDocumentService(),
          driverId: 'driver-test',
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Mi legajo de conductor'), findsOneWidget);
    expect(find.text('CARGAR'), findsWidgets);
    expect(find.text('DNI frente'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();

    expect(find.text('VTV / RTO vigente'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
