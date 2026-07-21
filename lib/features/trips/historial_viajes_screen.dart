import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../services/trip_service.dart';
import '../../services/driver_session_service.dart';

class HistorialViajesScreen extends StatefulWidget {
  const HistorialViajesScreen({super.key});

  @override
  State<HistorialViajesScreen> createState() => _HistorialViajesScreenState();
}

class _HistorialViajesScreenState extends State<HistorialViajesScreen> {
  bool _isLoading = true;
  List<TripModel> _trips = [];

  @override
  void initState() {
    super.initState();
    _cargarHistorial();
  }

  Future<void> _cargarHistorial() async {
    final driverId = DriverSessionService().id;
    final historial = await TripService.obtenerHistorialConductor(driverId);
    if (mounted) {
      setState(() {
        _trips = historial;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'QuiacaGo Conductor',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Historial de Viajes',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Registro real de servicios asignados y completados en La Quiaca.',
                    style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 20),

                  if (_trips.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.surfaceContainerHigh),
                      ),
                      child: Column(
                        children: const [
                          Icon(Icons.history_outlined, size: 48, color: AppColors.outline),
                          SizedBox(height: 12),
                          Text(
                            'Sin viajes registrados aún',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Los servicios aceptados y finalizados aparecerán aquí en tiempo real.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: AppColors.outline),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _trips.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final t = _trips[index];
                        final isCancelled = t.status == 'cancelled';
                        return _buildTripCard(
                          date: t.id.length > 8 ? 'ID: ${t.id.substring(0, 8)}...' : 'Viaje #${t.id}',
                          amount: isCancelled ? 'Cancelado' : '\$${t.fareAmount.toStringAsFixed(2)}',
                          origin: t.pickupAddress,
                          destination: t.destinationAddress,
                          passenger: 'Pasajero: ${t.passengerName} (${t.passengerPhone})',
                          isCancelled: isCancelled,
                        );
                      },
                    ),

                  const SizedBox(height: 40),
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
    String? passenger,
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
              Expanded(
                child: Text(
                  'Origen: $origin',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.circle, size: 12, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Destino: $destination',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.onSurfaceVariant),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (passenger != null) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 4),
            Text(passenger, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
          ],
        ],
      ),
    );
  }
}
