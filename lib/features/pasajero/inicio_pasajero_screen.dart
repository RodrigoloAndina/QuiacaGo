import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../services/location_service.dart';
import '../../services/tariff_service.dart';
import '../../services/trip_service.dart';
import '../../services/driver_location_service.dart';

enum EstadoPasajero { inicio, buscandoTaxi, taxiEnCamino, taxiLlego, enViaje, viajeFinalizado, cancelado }

class DestinoPredefinido {
  final String nombre;
  final LatLng ubicacion;
  final IconData icono;
  const DestinoPredefinido({required this.nombre, required this.ubicacion, required this.icono});
}

class InicioPasajeroScreen extends StatefulWidget {
  // Datos del pasajero logueado (se llenan desde el login)
  static String passengerName = 'Pasajero';
  static String passengerPhone = '';

  const InicioPasajeroScreen({super.key});

  @override
  State<InicioPasajeroScreen> createState() => _InicioPasajeroScreenState();
}

class _InicioPasajeroScreenState extends State<InicioPasajeroScreen> {
  EstadoPasajero _estado = EstadoPasajero.inicio;

  LatLng _pasajeroPos = const LatLng(AppConstants.laQuiacaLat, AppConstants.laQuiacaLng);
  LatLng _destinoPos = const LatLng(-22.1085, -65.5940);
  LatLng? _conductorPosRealtime;

  final TextEditingController _origenCtrl = TextEditingController(text: 'Mi Ubicación Actual (GPS)');
  final TextEditingController _destinoCtrl = TextEditingController(text: 'Terminal de Ómnibus');
  final MapController _mapController = MapController();
  StreamSubscription<LatLng>? _gpsSubscription;
  StreamSubscription<TripModel>? _tripStreamSub;
  Timer? _driverTrackingTimer;
  Timer? _driversRefreshTimer;

  TripModel? _viajeActual;
  String _motivoCancelacion = '';
  bool _isPanelMinimized = false;
  List<DriverLocationModel> _conductoresDisponibles = [];

  final List<DestinoPredefinido> _destinosFavoritos = const [
    DestinoPredefinido(nombre: 'Terminal de Ómnibus', ubicacion: LatLng(-22.1085, -65.5940), icono: Icons.directions_bus),
    DestinoPredefinido(nombre: 'Hospital Jorge Uro', ubicacion: LatLng(-22.1065, -65.6020), icono: Icons.local_hospital),
    DestinoPredefinido(nombre: 'Plaza Centenario', ubicacion: LatLng(-22.1045, -65.5980), icono: Icons.park),
    DestinoPredefinido(nombre: 'Puente Internacional', ubicacion: LatLng(-22.0965, -65.5960), icono: Icons.flag),
    DestinoPredefinido(nombre: 'Mercado Central', ubicacion: LatLng(-22.1030, -65.5975), icono: Icons.shopping_basket),
  ];

  @override
  void initState() {
    super.initState();
    _iniciarGPSReal();
    _cargarConductoresDisponibles();
    _driversRefreshTimer = Timer.periodic(const Duration(seconds: 8), (_) => _cargarConductoresDisponibles());
  }

  Future<void> _iniciarGPSReal() async {
    final posGps = await LocationService.getCurrentLocation();
    if (mounted) {
      setState(() => _pasajeroPos = posGps);
      _mapController.move(posGps, 16.2);
    }
    _gpsSubscription = LocationService.getRealtimeLocationStream().listen((pos) {
      if (mounted && _estado == EstadoPasajero.inicio) setState(() => _pasajeroPos = pos);
    });
  }

  Future<void> _cargarConductoresDisponibles() async {
    final conductores = await DriverLocationService.obtenerConductoresDisponibles();
    if (mounted) setState(() => _conductoresDisponibles = conductores);
  }

  void _seleccionarDestinoFav(DestinoPredefinido fav) {
    setState(() { _destinoPos = fav.ubicacion; _destinoCtrl.text = fav.nombre; });
    _mapController.move(fav.ubicacion, 16.0);
  }

  void _tocarPuntoEnMapa(LatLng punto) {
    if (_estado != EstadoPasajero.inicio) return;
    setState(() { _destinoPos = punto; _destinoCtrl.text = 'Punto Marcado en La Quiaca'; _isPanelMinimized = true; });
  }

  Future<void> _solicitarTaxi() async {
    final precio = TariffService.calcularPrecio();
    setState(() { _estado = EstadoPasajero.buscandoTaxi; _isPanelMinimized = false; });

    final trip = await TripService.solicitarViaje(
      passengerName: InicioPasajeroScreen.passengerName,
      passengerPhone: InicioPasajeroScreen.passengerPhone,
      pickupAddress: _origenCtrl.text,
      pickupLat: _pasajeroPos.latitude,
      pickupLng: _pasajeroPos.longitude,
      destinationAddress: _destinoCtrl.text,
      destinationLat: _destinoPos.latitude,
      destinationLng: _destinoPos.longitude,
      fareAmount: precio,
    );

    if (trip != null && mounted) {
      setState(() => _viajeActual = trip);
      _escucharEstadoViaje(trip.id);
    }
  }

  void _escucharEstadoViaje(String tripId) {
    _tripStreamSub?.cancel();
    _tripStreamSub = TripService.escucharViaje(tripId).listen((tripActualizado) {
      if (!mounted) return;
      setState(() => _viajeActual = tripActualizado);

      switch (tripActualizado.status) {
        case 'accepted':
          setState(() => _estado = EstadoPasajero.taxiEnCamino);
          _iniciarSeguimientoConductor(tripActualizado.driverId ?? '');
          break;
        case 'arrived':
          setState(() => _estado = EstadoPasajero.taxiLlego);
          break;
        case 'in_progress':
          setState(() => _estado = EstadoPasajero.enViaje);
          break;
        case 'completed':
          _detenerSeguimientoConductor();
          setState(() => _estado = EstadoPasajero.viajeFinalizado);
          break;
        case 'cancelled':
          _detenerSeguimientoConductor();
          setState(() => _estado = EstadoPasajero.cancelado);
          break;
      }
    });
  }

  void _iniciarSeguimientoConductor(String driverId) {
    if (driverId.isEmpty) return;
    _driverTrackingTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      final loc = await DriverLocationService.obtenerUbicacionConductor(driverId);
      if (mounted && loc != null) {
        setState(() => _conductorPosRealtime = loc.posicion);
      }
    });
  }

  void _detenerSeguimientoConductor() {
    _driverTrackingTimer?.cancel();
    _driverTrackingTimer = null;
  }

  void _cancelarViaje() {
    if (_viajeActual != null) {
      TripService.cancelarViaje(_viajeActual!.id, _motivoCancelacion);
    }
    _detenerSeguimientoConductor();
    _tripStreamSub?.cancel();
    setState(() { _estado = EstadoPasajero.cancelado; });
  }

  @override
  void dispose() {
    _gpsSubscription?.cancel();
    _tripStreamSub?.cancel();
    _driverTrackingTimer?.cancel();
    _driversRefreshTimer?.cancel();
    _mapController.dispose();
    _origenCtrl.dispose();
    _destinoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final precio = TariffService.calcularPrecio();
    final descTarifa = TariffService.getDescripcionTarifa();

    // Construir marcadores dinámicos
    final List<Marker> markers = [];

    // Marcador GPS del pasajero
    markers.add(Marker(
      point: _pasajeroPos, width: 44, height: 44, alignment: Alignment.center,
      child: Container(
        decoration: BoxDecoration(color: const Color(0xFF10B981), shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))]),
        child: const Center(child: Icon(Icons.person_pin_circle, color: Colors.white, size: 26)),
      ),
    ));

    // Marcadores de CONDUCTORES DISPONIBLES REALES (de Supabase)
    if (_estado == EstadoPasajero.inicio) {
      for (final c in _conductoresDisponibles) {
        markers.add(Marker(
          point: c.posicion, width: 44, height: 44, alignment: Alignment.center,
          child: Container(
            decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))]),
            child: const Center(child: Icon(Icons.local_taxi, color: Colors.white, size: 22)),
          ),
        ));
      }
    }

    // Marcador del conductor asignado en seguimiento en tiempo real
    if (_conductorPosRealtime != null && (_estado == EstadoPasajero.taxiEnCamino || _estado == EstadoPasajero.taxiLlego || _estado == EstadoPasajero.enViaje)) {
      markers.add(Marker(
        point: _conductorPosRealtime!, width: 48, height: 48, alignment: Alignment.center,
        child: Container(
          decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))]),
          child: const Center(child: Icon(Icons.directions_car, color: Colors.white, size: 26)),
        ),
      ));
    }

    // Destino si no está en modo pin-drop
    if (!_isPanelMinimized && _estado == EstadoPasajero.inicio) {
      markers.add(Marker(
        point: _destinoPos, width: 44, height: 44, alignment: Alignment.center,
        child: Container(
          decoration: BoxDecoration(color: const Color(0xFFEF4444), shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))]),
          child: const Center(child: Icon(Icons.location_on, color: Colors.white, size: 26)),
        ),
      ));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _pasajeroPos, initialZoom: 16.0,
              onTap: (_, point) => _tocarPuntoEnMapa(point),
              onPositionChanged: (pos, gesture) {
                if (_isPanelMinimized && gesture && pos.center != null) setState(() => _destinoPos = pos.center!);
              },
            ),
            children: [
              TileLayer(urlTemplate: 'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png', userAgentPackageName: 'com.quiacago.pasajero'),
              MarkerLayer(markers: markers),
            ],
          ),

          // Pin central en modo Uber
          if (_isPanelMinimized && _estado == EstadoPasajero.inicio)
            Center(
              child: Container(
                margin: const EdgeInsets.only(bottom: 35),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 32, height: 32, decoration: BoxDecoration(color: Colors.black, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))]),
                      child: const Center(child: Icon(Icons.square, color: Colors.white, size: 12))),
                    Container(width: 3, height: 22, color: Colors.black),
                  ],
                ),
              ),
            ),

          // Botón atrás
          Positioned(
            top: 44, left: 16,
            child: Container(
              decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 3))]),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () { if (_isPanelMinimized) { setState(() => _isPanelMinimized = false); } else { Navigator.pop(context); } },
              ),
            ),
          ),

          // Botón GPS
          if (_isPanelMinimized)
            Positioned(
              right: 16, bottom: 230,
              child: Container(
                decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 3))]),
                child: IconButton(icon: const Icon(Icons.my_location, color: Colors.black), onPressed: () => _mapController.move(_pasajeroPos, 16.2)),
              ),
            ),

          // Cantidad de taxis disponibles
          if (_estado == EstadoPasajero.inicio && _conductoresDisponibles.isNotEmpty)
            Positioned(
              top: 44, right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2))]),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_taxi, color: AppColors.primary, size: 18),
                    const SizedBox(width: 6),
                    Text('${_conductoresDisponibles.length} disponible${_conductoresDisponibles.length > 1 ? "s" : ""}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  ],
                ),
              ),
            ),

          // Panel inferior
          Positioned(left: 0, right: 0, bottom: 0, child: _buildPanel(precio, descTarifa)),
        ],
      ),
    );
  }

  Widget _buildPanel(double precio, String descTarifa) {
    switch (_estado) {
      case EstadoPasajero.inicio:
        if (_isPanelMinimized) {
          return Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24)), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -6))]),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 14),
                const Text('Marca tu destino', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
                const SizedBox(height: 4),
                const Text('Arrastra el mapa para mover el marcador', style: TextStyle(fontSize: 14, color: Colors.black54, fontWeight: FontWeight.w500)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      Container(width: 14, height: 14, decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.rectangle)),
                      const SizedBox(width: 12),
                      Expanded(child: Text(_destinoCtrl.text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton(
                    onPressed: () { setState(() => _isPanelMinimized = false); _solicitarTaxi(); },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.black, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: Text('Confirmar destino (${TariffService.formatearMonto(precio)})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            ),
          );
        }
        // Panel completo
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28)), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -6))]),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('¿A dónde vamos?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  IconButton(icon: const Icon(Icons.pin_drop_outlined, color: AppColors.primary), tooltip: 'Marcar en mapa', onPressed: () => setState(() => _isPanelMinimized = true)),
                ],
              ),
              const SizedBox(height: 10),
              TextField(controller: _origenCtrl, readOnly: true, decoration: InputDecoration(labelText: 'Punto de Recogida (GPS)', prefixIcon: const Icon(Icons.my_location, color: Color(0xFF10B981)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)))),
              const SizedBox(height: 10),
              TextField(controller: _destinoCtrl, readOnly: true, decoration: InputDecoration(labelText: 'Destino', prefixIcon: const Icon(Icons.location_on, color: Color(0xFFEF4444)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)))),
              const SizedBox(height: 12),
              const Text('DESTINOS PREDEFINIDOS:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.outline)),
              const SizedBox(height: 8),
              SizedBox(
                height: 38,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal, itemCount: _destinosFavoritos.length,
                  itemBuilder: (context, i) {
                    final fav = _destinosFavoritos[i];
                    final sel = _destinoCtrl.text == fav.nombre;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: FilterChip(selected: sel, avatar: Icon(fav.icono, size: 16, color: sel ? Colors.white : AppColors.primary), label: Text(fav.nombre, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: sel ? Colors.white : AppColors.textPrimary)), selectedColor: AppColors.primary, backgroundColor: AppColors.surfaceContainerLow, onSelected: (_) => _seleccionarDestinoFav(fav)),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('TARIFA OFICIAL MUNICIPAL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.outline)),
                    Text(descTarifa, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                  ]),
                  Text(TariffService.formatearMonto(precio), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.primary)),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity, height: 54,
                child: ElevatedButton.icon(
                  onPressed: _solicitarTaxi,
                  icon: const Icon(Icons.local_taxi, color: Colors.white, size: 22),
                  label: Text('PEDIR TAXI (${TariffService.formatearMonto(precio)})', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                ),
              ),
            ],
          ),
        );

      case EstadoPasajero.buscandoTaxi:
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28)), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -6))]),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 48, height: 48, child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3.5)),
              const SizedBox(height: 16),
              const Text('Buscando taxi habilitado...', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 6),
              Text('Solicitud enviada (${TariffService.formatearMonto(precio)})', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: _cancelarViaje,
                style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.statusCancelled), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: const Text('CANCELAR', style: TextStyle(color: AppColors.statusCancelled, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );

      case EstadoPasajero.taxiEnCamino:
        return Container(
          padding: const EdgeInsets.all(22),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28)), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -6))]),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Container(padding: const EdgeInsets.all(12), decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle), child: const Icon(Icons.directions_car, color: Colors.white, size: 28)),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('TU TAXI ESTÁ EN CAMINO', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.statusAvailable)),
                  Text(_viajeActual?.vehicleInfo ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  Text('Conductor: ${_viajeActual?.driverName ?? ""}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ])),
              ]),
              const SizedBox(height: 16),
              const Text('Seguí la ubicación del taxi en el mapa en tiempo real', style: TextStyle(fontSize: 12, color: AppColors.outline)),
            ],
          ),
        );

      case EstadoPasajero.taxiLlego:
        return Container(
          padding: const EdgeInsets.all(22),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28)), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -6))]),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: AppColors.statusAvailable, size: 40),
              const SizedBox(height: 10),
              const Text('TU TAXI LLEGÓ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              Text(_viajeActual?.vehicleInfo ?? '', style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.codeBoxBackground, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.primaryFixedDim)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('CÓDIGO PIN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.outline)),
                      Text('Decile este código al taxista', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ]),
                    Text(_viajeActual?.pinCode ?? '----', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: 6)),
                  ],
                ),
              ),
            ],
          ),
        );

      case EstadoPasajero.enViaje:
        return Container(
          padding: const EdgeInsets.all(22),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28)), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -6))]),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('EN VIAJE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.statusAvailable)),
                  Text(_destinoCtrl.text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                ]),
                Text(TariffService.formatearMonto(_viajeActual?.fareAmount ?? precio), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primary)),
              ]),
            ],
          ),
        );

      case EstadoPasajero.viajeFinalizado:
        return Container(
          padding: const EdgeInsets.all(22),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28)), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -6))]),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: AppColors.statusAvailable, size: 48),
              const SizedBox(height: 10),
              const Text('Viaje Finalizado', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              Text('Monto: ${TariffService.formatearMonto(_viajeActual?.fareAmount ?? precio)}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => setState(() { _estado = EstadoPasajero.inicio; _viajeActual = null; _conductorPosRealtime = null; }),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: const Text('PEDIR OTRO VIAJE', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );

      case EstadoPasajero.cancelado:
        return Container(
          padding: const EdgeInsets.all(22),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28)), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -6))]),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cancel_outlined, color: AppColors.statusCancelled, size: 44),
              const SizedBox(height: 10),
              const Text('Viaje Cancelado', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.statusCancelled)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => setState(() { _estado = EstadoPasajero.inicio; _viajeActual = null; _conductorPosRealtime = null; }),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: const Text('VOLVER AL INICIO', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
    }
  }
}
