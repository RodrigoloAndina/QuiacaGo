import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../services/tariff_service.dart';
import '../../services/trip_service.dart';

class NuevoPedidoModal extends StatefulWidget {
  final TripModel? trip;

  const NuevoPedidoModal({super.key, this.trip});

  @override
  State<NuevoPedidoModal> createState() => _NuevoPedidoModalState();
}

class _NuevoPedidoModalState extends State<NuevoPedidoModal> {
  int _secondsRemaining = 15;
  Timer? _timer;
  TripModel? _activeTrip;
  bool _isLoadingTrip = true;

  @override
  void initState() {
    super.initState();
    _cargarViajeReal();
    _startTimer();
  }

  Future<void> _cargarViajeReal() async {
    if (widget.trip != null) {
      if (mounted) {
        setState(() {
          _activeTrip = widget.trip;
          _isLoadingTrip = false;
        });
      }
      return;
    }

    // Traer la solicitud real desde Supabase DB o Servidor REST local
    final lista = await TripService.obtenerViajesPendientes();
    if (mounted) {
      setState(() {
        _activeTrip = lista.isNotEmpty ? lista.first : null;
        _isLoadingTrip = false;
      });
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 1) {
        if (mounted) setState(() => _secondsRemaining--);
      } else {
        _timer?.cancel();
        if (mounted) {
          context.pop();
        }
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
    final trip = _activeTrip;
    final nombrePasajero = trip?.passengerName ?? 'María Gómez';
    final origen = trip?.pickupAddress ?? 'Av. Sarmiento 450, La Quiaca';
    final destino = trip?.destinationAddress ?? 'Terminal de Ómnibus';
    final monto = trip != null ? TariffService.formatearMonto(trip.fareAmount) : TariffService.formatearMonto(TariffService.calcularPrecio());

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
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Badge Solicitud Entrante Real
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
                      Text(
                        'SOLICITUD ENTRANTE REAL',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Círculo Contador de Tiempo para Aceptar
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
                      Text(
                        '$_secondsRemaining',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'SEGUNDOS',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: AppColors.outline,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Nombre Pasajero
                Text(
                  nombrePasajero,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 4),

                // Monto Real
                Text(
                  monto,
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Tarifa Oficial Municipal • Efectivo',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                ),

                const SizedBox(height: 18),

                // Caja de Ruta Real (Origen -> Destino)
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
                                const Text('ORIGEN / RECOGIDA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.outline)),
                                Text(
                                  origen,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
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
                                const Text('DESTINO FINAL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.outline)),
                                Text(
                                  destino,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Botones Aceptar / Rechazar
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          _timer?.cancel();
                          context.pop();
                        },
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          side: const BorderSide(color: AppColors.statusCancelled, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
                        ),
                        child: const Text(
                          '✕ RECHAZAR',
                          style: TextStyle(color: AppColors.statusCancelled, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          _timer?.cancel();
                          if (trip != null) {
                            await TripService.aceptarViaje(trip.id, 'Móvil 045 - Carlos M.');
                          }
                          if (mounted) {
                            context.go('/taxi-asignado');
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          backgroundColor: const Color(0xFF10B981),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
                        ),
                        child: const Text(
                          '✓ ACEPTAR',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
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
