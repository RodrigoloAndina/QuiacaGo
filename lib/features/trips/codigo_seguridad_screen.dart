import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';

import '../../services/current_trip_session.dart';
import '../../services/location_service.dart';

class CodigoSeguridadScreen extends StatefulWidget {
  const CodigoSeguridadScreen({super.key});

  @override
  State<CodigoSeguridadScreen> createState() => _CodigoSeguridadScreenState();
}

class _CodigoSeguridadScreenState extends State<CodigoSeguridadScreen> {
  late final List<TextEditingController> _controllers;
  LatLng _posicionMapa = const LatLng(0, 0);

  @override
  void initState() {
    super.initState();
    final pin = CurrentTripSession().currentTrip?.pinCode ?? '1234';
    final p0 = pin.length > 0 ? pin[0] : '1';
    final p1 = pin.length > 1 ? pin[1] : '2';
    final p2 = pin.length > 2 ? pin[2] : '3';
    final p3 = pin.length > 3 ? pin[3] : '4';

    _controllers = [
      TextEditingController(text: p0),
      TextEditingController(text: p1),
      TextEditingController(text: p2),
      TextEditingController(text: p3),
    ];
    _cargarPosicion();
  }

  Future<void> _cargarPosicion() async {
    final trip = CurrentTripSession().currentTrip;
    if (trip != null && trip.pickupLat != 0.0 && trip.pickupLng != 0.0) {
      if (mounted) setState(() => _posicionMapa = LatLng(trip.pickupLat, trip.pickupLng));
    } else {
      final pos = await LocationService.getCurrentLocation();
      if (mounted) setState(() => _posicionMapa = pos);
    }
  }

  @override
  void dispose() {
    for (var c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: const [
            Icon(Icons.local_taxi, color: AppColors.primary, size: 24),
            SizedBox(width: 8),
            Text(
              'QuiacaGo Conductor',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: AppColors.onSurface, size: 24),
            onPressed: () {},
          ),
        ],
      ),
      body: Stack(
        children: [
          // Map
          FlutterMap(
            options: MapOptions(
              initialCenter: _posicionMapa.latitude == 0 ? const LatLng(-22.1024, -65.5998) : _posicionMapa,
              initialZoom: 16.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.quiacago.conductor',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _posicionMapa,
                    child: const Icon(Icons.person_pin_circle, color: AppColors.primary, size: 40),
                  ),
                ],
              ),
            ],
          ),

          // Bottom Sheet Stitch Screenshot 3
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 20,
                    offset: Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Passenger Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: const BoxDecoration(
                              color: AppColors.primaryFixedDim,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.person, color: AppColors.primary, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Juan P.',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.onSurface),
                              ),
                              SizedBox(height: 2),
                              Text(
                                '⭐ 4.9 • Pasajero',
                                style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chat_bubble_outline, color: AppColors.primary),
                            onPressed: () {},
                          ),
                          IconButton(
                            icon: const Icon(Icons.phone, color: AppColors.primary),
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),

                  // Route
                  Row(
                    children: const [
                      Icon(Icons.adjust, color: AppColors.secondary, size: 20),
                      SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Punto de encuentro', style: TextStyle(fontSize: 11, color: AppColors.outline)),
                          Text(
                            'Terminal de Ómnibus',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.onSurface),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: const [
                      Icon(Icons.location_on, color: AppColors.primary, size: 20),
                      SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Destino', style: TextStyle(fontSize: 11, color: AppColors.outline)),
                          Text(
                            'Barrio Santa Clara',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.onSurface),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // PIN Input Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Ingresar PIN del pasajero',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(4, (index) {
                            return Container(
                              width: 54,
                              height: 60,
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              child: TextField(
                                controller: _controllers[index],
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                maxLength: 1,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                                decoration: InputDecoration(
                                  counterText: '',
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(color: AppColors.outlineVariant),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Pídele al pasajero el código para iniciar',
                          style: TextStyle(fontSize: 12, color: AppColors.outline),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Boton Iniciar Viaje
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () => context.go('/viaje-en-curso'),
                      icon: const Icon(Icons.play_arrow, color: Colors.white),
                      label: const Text(
                        'Iniciar Viaje',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6B8BB9),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(40),
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
