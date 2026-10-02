import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';

import '../../services/current_trip_session.dart';
import '../../services/location_service.dart';
import '../../services/trip_service.dart';
import 'cancellation_dialog.dart';

class ConfirmacionLlegadaScreen extends StatefulWidget {
  const ConfirmacionLlegadaScreen({super.key});

  @override
  State<ConfirmacionLlegadaScreen> createState() =>
      _ConfirmacionLlegadaScreenState();
}

class _ConfirmacionLlegadaScreenState extends State<ConfirmacionLlegadaScreen> {
  LatLng _lugarEncuentro = const LatLng(0, 0);
  StreamSubscription<TripModel>? _tripSub;
  Timer? _waitTimer;
  Duration _remainingNoShow = const Duration(minutes: 5);
  bool _cancellingTrip = false;

  @override
  void initState() {
    super.initState();
    _cargarUbicacionReal();
    _escucharViaje();
    _iniciarEspera();
  }

  void _iniciarEspera() {
    final arrivedAt =
        CurrentTripSession().currentTrip?.arrivedAt ?? DateTime.now().toUtc();
    void update() {
      final elapsed = DateTime.now().toUtc().difference(arrivedAt);
      final remaining = const Duration(minutes: 5) - elapsed;
      if (!mounted) return;
      setState(() =>
          _remainingNoShow = remaining.isNegative ? Duration.zero : remaining);
    }

    update();
    _waitTimer = Timer.periodic(const Duration(seconds: 1), (_) => update());
  }

  void _escucharViaje() {
    final trip = CurrentTripSession().currentTrip;
    if (trip == null) return;
    _tripSub = TripService.escucharViaje(trip.id).listen((updated) {
      if (!mounted) return;
      if (updated.status == 'cancelled' || updated.status == 'requested') {
        if (_cancellingTrip) return;
        CurrentTripSession().clear();
        context.go('/home');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('El viaje fue cancelado. Ya estás disponible.'),
        ));
      } else {
        CurrentTripSession().setTrip(updated);
      }
    });
  }

  @override
  void dispose() {
    _tripSub?.cancel();
    _waitTimer?.cancel();
    super.dispose();
  }

  Future<void> _cargarUbicacionReal() async {
    final trip = CurrentTripSession().currentTrip;
    if (trip != null && trip.pickupLat != 0.0 && trip.pickupLng != 0.0) {
      if (mounted)
        setState(
            () => _lugarEncuentro = LatLng(trip.pickupLat, trip.pickupLng));
    } else {
      final pos = await LocationService.getCurrentLocation();
      if (mounted) setState(() => _lugarEncuentro = pos);
    }
  }

  Future<void> _hacerLlamada() async {
    final phone = CurrentTripSession().currentTrip?.passengerPhone ?? '';
    final Uri url = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Future<void> _abrirWhatsApp() async {
    final name = CurrentTripSession().currentTrip?.passengerName ?? 'Pasajero';
    final addr =
        CurrentTripSession().currentTrip?.pickupAddress ?? 'su ubicación';
    final phone = (CurrentTripSession().currentTrip?.passengerPhone ?? '')
        .replaceAll(RegExp(r'[^0-9]'), '');
    final Uri url = Uri.https('wa.me', '/$phone', {
      'text':
          'Hola $name, soy tu conductor de QuiacaGo. Ya estoy afuera esperándote en $addr.',
    });
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _cancelarYReasignar() async {
    final trip = CurrentTripSession().currentTrip;
    if (trip == null || _cancellingTrip) return;
    final choice = await showTripCancellationDialog(
      context,
      isDriver: true,
      allowPassengerNoShow: _remainingNoShow == Duration.zero,
    );
    if (choice == null || !mounted) return;
    setState(() => _cancellingTrip = true);
    final result = await TripService.cancelarViaje(
      tripId: trip.id,
      reasonCode: choice.code,
      reasonDetail: choice.detail,
    );
    if (!mounted) return;
    setState(() => _cancellingTrip = false);
    if (result == null || !result.success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(TripService.lastCancellationError ??
            'No se pudo cancelar el viaje.'),
      ));
      return;
    }
    await _tripSub?.cancel();
    CurrentTripSession().clear();
    if (mounted) {
      context.go('/home');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Esperando al Pasajero'),
        backgroundColor: AppColors.primary,
        automaticallyImplyLeading: false,
      ),
      body: Stack(
        children: [
          // Mapa Enfocado en el Punto de Encuentro
          FlutterMap(
            options: MapOptions(
              initialCenter: _lugarEncuentro.latitude == 0
                  ? const LatLng(-22.1024, -65.5998)
                  : _lugarEncuentro,
              initialZoom: 17.5,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.quiacago.quiaca_go_conductor',
              ),
              const RichAttributionWidget(attributions: [
                TextSourceAttribution('© OpenStreetMap contributors'),
              ]),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _lugarEncuentro,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black26, blurRadius: 10)
                        ],
                      ),
                      child: const Icon(Icons.directions_car,
                          color: Colors.white, size: 30),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.statusPending.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.access_time_filled,
                            color: AppColors.statusPending, size: 18),
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
                  Text(
                    CurrentTripSession().currentTrip?.pickupAddress ??
                        'Punto de recogida',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pasajero: ${CurrentTripSession().currentTrip?.passengerName ?? 'Pasajero'}',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary),
                  ),

                  const SizedBox(height: 20),

                  // BOTONES DE LLAMADA Y MENSAJE DIRECTO AL PASAJERO
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _hacerLlamada,
                          icon:
                              const Icon(Icons.phone, color: AppColors.primary),
                          label: const Text('LLAMAR',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: const BorderSide(color: AppColors.primary),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _abrirWhatsApp,
                          icon: const Icon(Icons.chat_outlined,
                              color: Colors.white),
                          label: const Text('WHATSAPP',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.statusAvailable,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
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
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _cancellingTrip ? null : _cancelarYReasignar,
                    icon: const Icon(Icons.cancel_outlined),
                    label: Text(_cancellingTrip
                        ? 'CANCELANDO...'
                        : _remainingNoShow == Duration.zero
                            ? 'CANCELAR / PASAJERO AUSENTE'
                            : 'CANCELAR O REASIGNAR · AUSENTE EN ${_remainingNoShow.inMinutes}:${(_remainingNoShow.inSeconds % 60).toString().padLeft(2, '0')}'),
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.statusCancelled),
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
