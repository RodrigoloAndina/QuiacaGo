import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class HistorialViajesScreen extends StatelessWidget {
  const HistorialViajesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const Icon(Icons.menu, color: AppColors.onSurface, size: 28),
        title: const Text(
          'QuiacaGo',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w800,
            fontSize: 22,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              backgroundColor: AppColors.primary,
              child: const Text('👤', style: TextStyle(fontSize: 18)),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mis Viajes',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Revisa tu historial de recorridos por la región.',
              style: TextStyle(fontSize: 14, color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 24),

            // Card 1
            _buildTripCard(
              date: '📅 12 OCT 2023 • 14:30',
              amount: '\$1,250',
              origin: 'Plaza de la República',
              destination: 'Terminal de Ómnibus',
              driver: 'Conductor: Carlos M. ⭐⭐⭐⭐⭐',
              hasBorderLeft: true,
            ),
            const SizedBox(height: 16),

            // Card 2
            _buildTripCard(
              date: '📅 08 OCT 2023 • 09:15',
              amount: '\$850',
              origin: 'Mercado Central',
              destination: 'Barrio Santa Clara',
              driver: 'Conductora: Laura G. ⭐⭐⭐⭐⭐',
            ),
            const SizedBox(height: 16),

            // Card 3 (Cancelado)
            _buildTripCard(
              date: '📅 05 OCT 2023 • 18:45',
              amount: 'Cancelado',
              origin: 'Hospital Jorge Uro',
              destination: 'Centro Cívico',
              isCancelled: true,
            ),

            const SizedBox(height: 28),

            // Cargar más viajes
            Center(
              child: OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(200, 48),
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(40),
                  ),
                ),
                child: const Text(
                  'Cargar más viajes',
                  style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildTripCard({
    required String date,
    required String amount,
    required String origin,
    required String destination,
    String? driver,
    bool hasBorderLeft = false,
    bool isCancelled = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: hasBorderLeft
            ? const Border(left: BorderSide(color: AppColors.primary, width: 4))
            : Border.all(color: AppColors.surfaceContainerHigh),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(date, style: const TextStyle(fontSize: 12, color: AppColors.outline)),
              if (isCancelled)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.badgeCancelledBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Cancelado',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.statusCancelled,
                    ),
                  ),
                )
              else
                Text(
                  amount,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.circle, size: 12, color: AppColors.secondary),
              const SizedBox(width: 8),
              Text(
                'Origen: $origin',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.onSurface),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.circle, size: 12, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Destino: $destination',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.onSurfaceVariant),
              ),
            ],
          ),
          if (driver != null) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(driver, style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.surfaceContainerHigh,
                    foregroundColor: AppColors.primary,
                    minimumSize: const Size(90, 32),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text('Ver Detalles', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
