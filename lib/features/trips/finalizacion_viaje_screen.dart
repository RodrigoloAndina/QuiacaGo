import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../services/current_trip_session.dart';
import '../../services/tariff_service.dart';
import '../../services/trip_service.dart';
import '../../services/offline_sync_service.dart';

class FinalizacionViajeScreen extends StatefulWidget {
  const FinalizacionViajeScreen({super.key});
  @override
  State<FinalizacionViajeScreen> createState() =>
      _FinalizacionViajeScreenState();
}

class _FinalizacionViajeScreenState extends State<FinalizacionViajeScreen> {
  final _code = TextEditingController();
  StreamSubscription<TripModel>? _subscription;
  bool _validating = false;
  bool _waitingPayment = false;
  bool _reportingUnpaid = false;
  bool _confirmingCash = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final trip = CurrentTripSession().currentTrip;
    if (trip != null) {
      _waitingPayment = trip.status == 'payment_pending';
      _subscription = TripService.escucharViaje(trip.id).listen((updated) {
        if (!mounted) return;
        CurrentTripSession().setTrip(updated);
        if (updated.status == 'completed') {
          // El chofer conserva el tracking activo. Al volver al inicio, la
          // pantalla detecta la sesión online y continúa recibiendo pedidos.
          CurrentTripSession().clear();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(updated.paymentStatus == 'disputed'
                  ? 'Reclamo registrado. Soporte resolverá el pago.'
                  : 'Viaje finalizado. Seguís conectado y disponible.')));
          context.go('/home');
        }
      });
    }
  }

  Future<void> _validate() async {
    final trip = CurrentTripSession().currentTrip;
    if (trip == null || _code.text.length != 4) {
      setState(() => _error = 'Ingresá los cuatro dígitos del pasajero.');
      return;
    }
    if (!await OfflineSyncService().checkNow()) {
      if (mounted) {
        setState(() => _error =
            'Sin conexión. El código no fue consumido; reintentá cuando vuelva internet.');
      }
      return;
    }
    setState(() {
      _validating = true;
      _error = null;
    });
    final ok = await TripService.validarCodigoFinalizacion(trip.id, _code.text);
    if (!mounted) return;
    setState(() {
      _validating = false;
      _waitingPayment = ok;
    });
    if (ok) {
      CurrentTripSession().setTrip(trip.copyWithStatus('payment_pending'));
    }
    if (!ok)
      setState(() => _error = 'Código incorrecto, vencido o ya utilizado.');
  }

  Future<void> _reportUnpaid() async {
    final trip = CurrentTripSession().currentTrip;
    if (trip == null || _reportingUnpaid) return;
    String reason = 'refused_to_pay';
    final notes = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Informar pago no recibido'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text(
                'El viaje se cerrará y soporte revisará el caso. No confrontes ni retengas al pasajero.',
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: reason,
                decoration: const InputDecoration(labelText: 'Motivo'),
                items: const [
                  DropdownMenuItem(
                      value: 'refused_to_pay', child: Text('Se negó a pagar')),
                  DropdownMenuItem(
                      value: 'insufficient_cash',
                      child: Text('No tenía efectivo suficiente')),
                  DropdownMenuItem(
                      value: 'passenger_left',
                      child: Text('Se retiró sin pagar')),
                  DropdownMenuItem(
                      value: 'payment_disagreement',
                      child: Text('Desacuerdo sobre el importe')),
                  DropdownMenuItem(value: 'other', child: Text('Otro motivo')),
                ],
                onChanged: (value) =>
                    setDialogState(() => reason = value ?? reason),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notes,
                maxLength: 500,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Detalle para soporte',
                  hintText: 'Describí brevemente qué ocurrió',
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('CANCELAR')),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.statusCancelled),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('REGISTRAR RECLAMO'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) {
      notes.dispose();
      return;
    }
    setState(() {
      _reportingUnpaid = true;
      _error = null;
    });
    final error = await TripService.reportarPagoNoRecibido(
      tripId: trip.id,
      reasonCode: reason,
      notes: notes.text,
    );
    notes.dispose();
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _reportingUnpaid = false;
        _error = error;
      });
      return;
    }
    CurrentTripSession().clear();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Reclamo registrado. Soporte resolverá el pago.'),
    ));
    context.go('/home');
  }

  Future<void> _confirmCash() async {
    final trip = CurrentTripSession().currentTrip;
    if (trip == null || _confirmingCash || _reportingUnpaid) return;
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Confirmar efectivo recibido'),
              content: Text(
                  '¿Recibiste ${TariffService.formatearMonto(trip.fareAmount)}? Esto cierra el viaje como cobrado.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('VOLVER')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('SÍ, RECIBÍ EL EFECTIVO'))
              ],
            ));
    if (confirmed != true || !mounted) return;
    setState(() => _confirmingCash = true);
    final error = await TripService.confirmarPagoRecibido(trip.id);
    if (!mounted) return;
    setState(() {
      _confirmingCash = false;
      _error = error;
    });
    if (error == null) {
      CurrentTripSession().clear();
      context.go('/home');
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trip = CurrentTripSession().currentTrip;
    return Scaffold(
      appBar: AppBar(
          title: const Text('Finalizar viaje'),
          backgroundColor: AppColors.primary,
          actions: [
            IconButton(
              tooltip: 'Ayuda y emergencia',
              onPressed: () => context.push('/soporte'),
              icon: const Icon(Icons.support_agent_outlined),
            ),
          ]),
      body: Center(
          child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Card(
                child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                    _waitingPayment
                        ? Icons.payments_outlined
                        : Icons.pin_outlined,
                    size: 64,
                    color: AppColors.primary),
                const SizedBox(height: 16),
                Text(
                    _waitingPayment
                        ? 'Esperando confirmación del pago'
                        : 'Código de finalización',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                    _waitingPayment
                        ? 'Cobrá ${TariffService.formatearMonto(trip?.fareAmount ?? 0)} en efectivo y confirmá cuando lo recibas.'
                        : 'Pedile al pasajero el segundo código. Es diferente al código de inicio y funciona una sola vez.',
                    textAlign: TextAlign.center),
                if (!_waitingPayment) ...[
                  const SizedBox(height: 24),
                  TextField(
                      controller: _code,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 30,
                          letterSpacing: 12,
                          fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                          labelText: 'Código de 4 dígitos',
                          border: OutlineInputBorder())),
                  if (_error != null)
                    Text(_error!,
                        style: const TextStyle(
                            color: Colors.red, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 14),
                  SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _validating ? null : _validate,
                        child: Text(
                            _validating ? 'VALIDANDO…' : 'VALIDAR Y COBRAR'),
                      )),
                ] else ...[
                  const SizedBox(height: 24),
                  FilledButton(
                      onPressed: _confirmingCash || _reportingUnpaid
                          ? null
                          : _confirmCash,
                      child: Text(_confirmingCash
                          ? 'CONFIRMANDO…'
                          : 'RECIBÍ EL EFECTIVO')),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _reportingUnpaid || _confirmingCash
                          ? null
                          : _reportUnpaid,
                      style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.statusCancelled),
                      icon: _reportingUnpaid
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.report_problem_outlined),
                      label: Text(_reportingUnpaid
                          ? 'REGISTRANDO...'
                          : 'NO RECIBÍ EL PAGO'),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(_error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: AppColors.statusCancelled,
                            fontWeight: FontWeight.w700)),
                  ],
                ],
              ]),
            ))),
      )),
    );
  }
}
