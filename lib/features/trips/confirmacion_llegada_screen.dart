import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';

import '../../services/current_trip_session.dart';
import '../../services/location_service.dart';

class ConfirmacionLlegadaScreen extends StatefulWidget {
  const ConfirmacionLlegadaScreen({super.key});

  @override
  State<ConfirmacionLlegadaScreen> createState() => _ConfirmacionLlegadaScreenState();
}

class _ConfirmacionLlegadaScreenState extends State<ConfirmacionLlegadaScreen> {
  LatLng _lugarEncuentro = const LatLng(0, 0);

  @override
  void initState() {
    super.initState();
    _cargarUbicacionReal();
  }

  Future<void> _cargarUbicacionReal() async {
    final trip = CurrentTripSession().currentTrip;
    if (trip != null && trip.pickupLat != 0.0 && trip.pickupLng != 0.0) {
      if (mounted) setState(() => _lugarEncuentro = LatLng(trip.pickupLat, trip.pickupLng));
    } else {
      final pos = await LocationService.getCurrentLocation();
      if (mounted) setState(() => _lugarEncuentro = pos);
    }
  }

  Future<void> _hacerLlamada() async {
    final Uri url = Uri.parse('tel:+5493885401234');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Future<void> _abrirWhatsApp() async {
    final name = CurrentTripSession().currentTrip?.passengerName ?? 'Pasajero';
    final addr = CurrentTripSession().currentTrip?.pickupAddress ?? 'su ubicación';
    final Uri url = Uri.parse('https://wa.me/5493885401234?text=Hola%20$name,%20soy%20el%20conductor%20de%20QuiacaGo.%20Ya%20estoy%20esperándote%20en%20$addr.');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Esperando al Pasajero'),
        backgroundColor: AppColors.primary,
      ),
      body: Stack(
        children: [
          // Mapa Enfocado en el Punto de Encuentro
          FlutterMap(
            options: MapOptions(
              initialCenter: _lugarEncuentro.latitude == 0 ? const LatLng(-22.1024, -65.5998) : _lugarEncuentro,
              initialZoom: 17.5,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png',
                userAgentPackageName: 'com.quiacago.quiaca_go_conductor',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _lugarEncuentro,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
                      ),
                      child: const Icon(Icons.directions_car, color: Colors.white, size: 30),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Sheet Inferior de Notificación al Pasajero
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Tag de Estado
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.statusPending.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.access_time_filled, color: AppColors.statusPending, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'ESPERANDO EN EL PUNTO DE RECOGIDA',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.statusPending,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Text(
                    'Av. Sarmiento 450',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Pasajero: María Gómez',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                  ),

                  const SizedBox(height: 20),

                  // BOTONES DE LLAMADA Y MENSAJE DIRECTO AL PASAJERO
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _hacerLlamada,
                          icon: const Icon(Icons.phone, color: AppColors.primary),
                          label: const Text('LLAMAR', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: const BorderSide(color: AppColors.primary),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _abrirWhatsApp,
                          icon: const Icon(Icons.chat_outlined, color: Colors.white),
                          label: const Text('WHATSAPP', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.statusAvailable,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Botón ingresar PIN para iniciar viaje
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () => context.push('/codigo-seguridad'),
                      icon: const Icon(Icons.lock_open, color: Colors.white),
                      label: const Text(
                        'INGRESAR PIN E INICIAR VIAJE',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
