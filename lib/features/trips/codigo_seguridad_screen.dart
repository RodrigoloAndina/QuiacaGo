import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/map_bottom_panel.dart';

import '../../services/current_trip_session.dart';
import '../../services/location_service.dart';
import '../../services/offline_sync_service.dart';
import '../../services/trip_service.dart';

class CodigoSeguridadScreen extends StatefulWidget {
  const CodigoSeguridadScreen({super.key});

  @override
  State<CodigoSeguridadScreen> createState() => _CodigoSeguridadScreenState();
}

class _CodigoSeguridadScreenState extends State<CodigoSeguridadScreen> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;
  LatLng _posicionMapa = const LatLng(0, 0);
  bool _validating = false;
  String? _codeError;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(4, (_) => TextEditingController());
    _focusNodes = List.generate(4, (_) => FocusNode());
    _cargarPosicion();
  }

  Future<void> _validarEIniciar() async {
    final trip = CurrentTripSession().currentTrip;
    final code = _controllers.map((c) => c.text).join();
    if (trip == null || code.length != 4) {
      setState(() => _codeError = 'Ingresá los cuatro dígitos.');
      return;
    }
    if (!await OfflineSyncService().checkNow()) {
      if (mounted) {
        setState(() => _codeError =
            'Sin conexión. El viaje no se inició; reintentá cuando vuelva internet.');
      }
      return;
    }
    setState(() {
      _validating = true;
      _codeError = null;
    });
    final ok = await TripService.validarPinIniciarViaje(trip.id, code);
    if (!mounted) return;
    setState(() => _validating = false);
    if (ok) {
      CurrentTripSession().setTrip(trip.copyWithStatus('in_progress'));
      context.go('/viaje-en-curso');
    } else {
      setState(() => _codeError = 'Código incorrecto, vencido o ya utilizado.');
      for (final controller in _controllers) {
        controller.clear();
      }
      _focusNodes.first.requestFocus();
    }
  }

  Future<void> _cargarPosicion() async {
    final trip = CurrentTripSession().currentTrip;
    if (trip != null && trip.pickupLat != 0.0 && trip.pickupLng != 0.0) {
      if (mounted)
        setState(() => _posicionMapa = LatLng(trip.pickupLat, trip.pickupLng));
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
    for (final node in _focusNodes) {
      node.dispose();
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
        title: const Row(
          children: [
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
            tooltip: 'Ayuda y emergencia',
            icon: const Icon(Icons.support_agent_outlined,
                color: AppColors.onSurface, size: 24),
            onPressed: () => context.push('/soporte'),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Map
          FlutterMap(
            options: MapOptions(
              initialCenter: _posicionMapa.latitude == 0
                  ? const LatLng(-22.1024, -65.5998)
                  : _posicionMapa,
              initialZoom: 16.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.quiacago.conductor',
              ),
              const RichAttributionWidget(attributions: [
                TextSourceAttribution('© OpenStreetMap contributors'),
              ]),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _posicionMapa,
                    child: const Icon(Icons.person_pin_circle,
                        color: AppColors.primary, size: 40),
                  ),
                ],
              ),
            ],
          ),

          // Bottom Sheet Stitch Screenshot 3
          Positioned.fill(
            child: MapBottomPanel(
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
                              child: const Icon(Icons.person,
                                  color: AppColors.primary, size: 24),
                            ),
                            const SizedBox(width: 14),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  CurrentTripSession()
                                          .currentTrip
                                          ?.passengerName ??
                                      'Pasajero',
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.onSurface),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  '⭐ 4.9 • Pasajero',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chat_bubble_outline,
                                  color: AppColors.primary),
                              onPressed: () {},
                            ),
                            IconButton(
                              icon: const Icon(Icons.phone,
                                  color: AppColors.primary),
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
                      children: [
                        const Icon(Icons.adjust,
                            color: AppColors.secondary, size: 20),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Punto de encuentro',
                                style: TextStyle(
                                    fontSize: 11, color: AppColors.outline)),
                            Text(
                              CurrentTripSession().currentTrip?.pickupAddress ??
                                  'Punto de encuentro',
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.onSurface),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            color: AppColors.primary, size: 20),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Destino',
                                style: TextStyle(
                                    fontSize: 11, color: AppColors.outline)),
                            Text(
                              CurrentTripSession()
                                      .currentTrip
                                      ?.destinationAddress ??
                                  'Destino',
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.onSurface),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    if (_codeError != null) ...[
                      Text(_codeError!,
                          style: const TextStyle(
                              color: Colors.red, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                    ],

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
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.onSurface),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(4, (index) {
                              return Container(
                                width: 54,
                                height: 60,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 6),
                                child: TextField(
                                  controller: _controllers[index],
                                  focusNode: _focusNodes[index],
                                  autofocus: index == 0,
                                  keyboardType: TextInputType.number,
                                  textInputAction: index < 3
                                      ? TextInputAction.next
                                      : TextInputAction.done,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  textAlign: TextAlign.center,
                                  maxLength: 1,
                                  onChanged: (value) {
                                    if (value.isNotEmpty) {
                                      if (index < 3) {
                                        _focusNodes[index + 1].requestFocus();
                                      } else {
                                        _focusNodes[index].unfocus();
                                      }
                                    } else if (index > 0) {
                                      _focusNodes[index - 1].requestFocus();
                                    }
                                  },
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
                                      borderSide: const BorderSide(
                                          color: AppColors.outlineVariant),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Pídele al pasajero el código para iniciar',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.outline),
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
                        onPressed: _validating ? null : _validarEIniciar,
                        icon: const Icon(Icons.play_arrow, color: Colors.white),
                        label: const Text(
                          'Iniciar Viaje',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800),
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
          ),
        ],
      ),
    );
  }
}
