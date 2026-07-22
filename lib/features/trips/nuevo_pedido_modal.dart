import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../services/tariff_service.dart';
import '../../services/trip_service.dart';
import '../../services/current_trip_session.dart';

class NuevoPedidoModal extends StatefulWidget {
  final TripModel? trip;
  final String driverId;
  final String driverName;
  final String vehicleInfo;

  const NuevoPedidoModal({
    super.key,
    this.trip,
    this.driverId = '',
    this.driverName = '',
    this.vehicleInfo = '',
  });

  @override
  State<NuevoPedidoModal> createState() => _NuevoPedidoModalState();
}

class _NuevoPedidoModalState extends State<NuevoPedidoModal> {
  int _secondsRemaining = 15;
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    // Si no hay viaje real, cerrar inmediatamente
    if (widget.trip == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
      return;
    }

    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 1) {
        if (mounted) setState(() => _secondsRemaining--);
      } else {
        _timer?.cancel();
        if (mounted) Navigator.pop(context);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    if (trip == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: Colors.black54,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            padding: const EdgeInsets.all(28.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 30, offset: const Offset(0, 10)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryFixedDim.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.hail, color: AppColors.primary, size: 16),
                      SizedBox(width: 6),
                      Text('SOLICITUD DE VIAJE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary, letterSpacing: 1.0)),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Contador
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 7),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$_secondsRemaining', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: AppColors.primary, height: 1)),
                      const SizedBox(height: 4),
                      const Text('SEGUNDOS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.outline, letterSpacing: 1.0)),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Nombre Pasajero Real
                Text(trip.passengerName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(height: 4),

                // Monto Real
                Text(
                  TariffService.formatearMonto(trip.fareAmount),
                  style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: AppColors.primary),
                ),
                const SizedBox(height: 2),
                const Text('Tarifa Oficial Municipal', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),

                const SizedBox(height: 18),

                // Ruta Real
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.surfaceContainerHighest),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.my_location, color: Color(0xFF10B981), size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('RECOGIDA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.outline)),
                                Text(trip.pickupAddress, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary), maxLines: 2, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.location_on, color: Color(0xFFEF4444), size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('DESTINO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.outline)),
                                Text(trip.destinationAddress, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary), maxLines: 2, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Botones
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          _timer?.cancel();
                          Navigator.pop(context);
                        },
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          side: const BorderSide(color: AppColors.statusCancelled, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
                        ),
                        child: const Text('RECHAZAR', style: TextStyle(color: AppColors.statusCancelled, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          _timer?.cancel();
                          if (trip != null) {
                            CurrentTripSession().setTrip(trip);
                          }
                          final ok = await TripService.aceptarViaje(
                            tripId: trip?.id ?? '',
                            driverId: widget.driverId,
                            driverName: widget.driverName,
                            vehicleInfo: widget.vehicleInfo,
                          );
                          if (mounted) {
                            Navigator.pop(context);
                            if (ok) {
                              context.go('/taxi-asignado');
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          backgroundColor: const Color(0xFF10B981),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
                        ),
                        child: const Text('ACEPTAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
