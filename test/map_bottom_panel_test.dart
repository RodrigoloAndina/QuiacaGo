import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiaca_go_conductor/core/widgets/map_bottom_panel.dart';

void main() {
  for (final height in [760.0, 540.0]) {
    testWidgets('mantiene la acción sobre la navegación a ${height.toInt()} px',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(347, height));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(347, 760),
              viewPadding: EdgeInsets.only(bottom: 24),
              padding: EdgeInsets.only(bottom: 24),
            ),
            child: Scaffold(
              body: Stack(
                children: [
                  const ColoredBox(color: Colors.blue),
                  Positioned.fill(
                    child: MapBottomPanel(
                      child: Container(
                        color: Colors.white,
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 500),
                            ElevatedButton(
                              onPressed: () {},
                              child: const Text('INICIAR VIAJE'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      final button = find.text('INICIAR VIAJE');
      expect(button, findsOneWidget);
      expect(tester.getBottomLeft(button).dy, lessThanOrEqualTo(height - 24));
      expect(tester.takeException(), isNull);
    });
  }
}
