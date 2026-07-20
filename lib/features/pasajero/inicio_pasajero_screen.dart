import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../services/location_service.dart';

enum EstadoPasajero {
  inicio,           // Seleccionando origen y destino
  buscandoTaxi,     // Esperando que un chofer acepte
  taxiEnCamino,     // Chofer aceptó y va en camino
  enViaje,          // Pasajero a bordo viajando al destino
  viajeFinalizado   // Viaje completado
}

class InicioPasajeroScreen extends StatefulWidget {
  const InicioPasajeroScreen({super.key});

  @override
  State<InicioPasajeroScreen> createState() => _InicioPasajeroScreenState();
}

class _InicioPasajeroScreenState extends State<InicioPasajeroScreen> {
  EstadoPasajero _estado = EstadoPasajero.inicio;
  LatLng _pasajeroPos = const LatLng(-22.1024, -65.5998); // Av. Sarmiento 450
  final LatLng _destinoPos = const LatLng(-22.1085, -65.5940); // Terminal de Ómnibus
  LatLng _conductorPos = const LatLng(-22.1055, -65.5985); // Taxi Móvil 045

  final TextEditingController _origenCtrl = TextEditingController(text: 'Av. Sarmiento 450');
  final TextEditingController _destinoCtrl = TextEditingController(text: 'Terminal de Ómnibus');
  final MapController _mapController = MapController();
  Timer? _timerSimuladorAccion;

  @override
  void initState() {
    super.initState();
    _obtenerUbicacionReal();
  }

  Future<void> _obtenerUbicacionReal() async {
    final posReal = await LocationService.getCurrentLocation();
    if (mounted) {
      setState(() {
        _pasajeroPos = posReal;
      });
      _mapController.move(posReal, 16.0);
    }
  }

  void _solicitarTaxi() {
    setState(() {
      _estado = EstadoPasajero.buscandoTaxi;
    });

    // Simular que un chofer en la zona acepta el pedido en 3 segundos si no hay chofer real conectado
    _timerSimuladorAccion = Timer(const Duration(seconds: 4), () {
      if (mounted && _estado == EstadoPasajero.buscandoTaxi) {
        setState(() {
          _estado = EstadoPasajero.taxiEnCamino;
        });
      }
    });
  }

  void _cancelarSolicitud() {
    _timerSimuladorAccion?.cancel();
    setState(() {
      _estado = EstadoPasajero.inicio;
    });
  }

  Future<void> _llamarChofer() async {
    final Uri url = Uri.parse('tel:+5493885401234');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  void dispose() {
    _timerSimuladorAccion?.cancel();
    _mapController.dispose();
    _origenCtrl.dispose();
    _destinoCtrl.dispose();
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
            Icon(Icons.local_taxi, color: AppColors.primary, size: 26),
            SizedBox(width: 8),
            Text(
              'QuiacaGo Pasajero',
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
            icon: const Icon(Icons.person_outline, color: AppColors.primary),
            onPressed: () {},
          ),
        ],
      ),
      body: Stack(
        children: [
          // MAPA INTERACTIVO HD DE LA QUIACA
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _pasajeroPos,
              initialZoom: 16.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png',
                userAgentPackageName: 'com.quiacago.quiaca_go_pasajero',
              ),
              MarkerLayer(
                markers: [
                  // Marcador Pasajero
                  Marker(
                    point: _pasajeroPos,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
                      ),
                      child: const Icon(Icons.person_pin_circle, color: Colors.white, size: 26),
                    ),
                  ),
                  // Marcador Taxi Cercano Habilitado
                  Marker(
                    point: _conductorPos,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
                      ),
                      child: const Icon(Icons.directions_car, color: Colors.white, size: 24),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // SHEET SEGÚN EL ESTADO DE LA SOLICITUD DEL PASAJERO
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: _buildPanelSegunEstado(),
          ),
        ],
      ),
    );
  }

  Widget _buildPanelSegunEstado() {
    switch (_estado) {
      case EstadoPasajero.inicio:
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '¿A dónde vamos hoy en La Quiaca?',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 16),

              // Origen
              TextField(
                controller: _origenCtrl,
                decoration: InputDecoration(
                  labelText: 'Punto de Recogida',
                  prefixIcon: const Icon(Icons.my_location, color: AppColors.statusAvailable),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 10),

              // Destino
              TextField(
                controller: _destinoCtrl,
                decoration: InputDecoration(
                  labelText: 'Destino Final',
                  prefixIcon: const Icon(Icons.location_on, color: AppColors.statusCancelled),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),

              const SizedBox(height: 16),

              // Tarifa estimada y Forma de pago
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.payments_outlined, color: AppColors.primary, size: 20),
                      SizedBox(width: 6),
                      Text('Efectivo', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.codeBoxBackground,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'Est: \$ 1,250',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primary),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _solicitarTaxi,
                  icon: const Icon(Icons.local_taxi, color: Colors.white, size: 22),
                  label: const Text(
                    'PEDIR TAXI HABILITADO AHORA',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                ),
              ),
            ],
          ),
        );

      case EstadoPasajero.buscandoTaxi:
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
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
              const SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3.5),
              ),
              const SizedBox(height: 16),
              const Text(
                'Buscando taxi cercano en La Quiaca...',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              const Text(
                'Notificando a los móviles disponibles registrados en la Municipalidad',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: _cancelarSolicitud,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.statusCancelled),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('CANCELAR BÚSQUEDA', style: TextStyle(color: AppColors.statusCancelled, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );

      case EstadoPasajero.taxiEnCamino:
        return Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.directions_car, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '¡TAXI ASIGNADO!',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.statusAvailable),
                        ),
                        Text(
                          'Móvil 045 • Chevrolet Corsa',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        Text('Conductor: Carlos M. (⭐ 4.9)', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.phone, color: AppColors.primary),
                    onPressed: _llamarChofer,
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),

              // CÓDIGO PIN DE SEGURIDAD PARA DAR AL CHOFER
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.codeBoxBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primaryFixedDim),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TU PIN DE SEGURIDAD',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.outline),
                        ),
                        Text(
                          'Dícelo al taxista para iniciar el viaje',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    Text(
                      '4 8 2 1',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: 3),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _estado = EstadoPasajero.enViaje;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('SUBÍ AL TAXI / EN VIAJE', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );

      case EstadoPasajero.enViaje:
        return Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('EN VIAJE A TU DESTINO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.statusAvailable)),
                      Text('Terminal de Ómnibus', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    ],
                  ),
                  Text('\$ 1,250', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primary)),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _estado = EstadoPasajero.viajeFinalizado;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.statusAvailable,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('LLEGUÉ A DESTINO / LLEGADA', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );

      case EstadoPasajero.viajeFinalizado:
        return Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
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
              const Icon(Icons.check_circle, color: AppColors.statusAvailable, size: 48),
              const SizedBox(height: 10),
              const Text('¡Gracias por viajar en QuiacaGo!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const Text('Total abonado en efectivo: \$1,250', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _cancelarSolicitud,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('PEDIR OTRO VIAJE', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
    }
  }
}
