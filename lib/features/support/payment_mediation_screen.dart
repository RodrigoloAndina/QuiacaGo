import 'package:flutter/material.dart';
import '../../services/payment_dispute_service.dart';
import '../../services/tariff_service.dart';

class PaymentMediationScreen extends StatefulWidget {
  const PaymentMediationScreen({super.key});
  @override
  State<PaymentMediationScreen> createState() => _PaymentMediationScreenState();
}
class _PaymentMediationScreenState extends State<PaymentMediationScreen> {
  late Future<List<Map<String, dynamic>>> _cases;
  @override
  void initState() { super.initState(); _cases = PaymentDisputeService().listMine(); }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Reclamos de pago')),
    body: FutureBuilder<List<Map<String, dynamic>>>(future: _cases, builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
      return RefreshIndicator(onRefresh: () async { setState(() => _cases = PaymentDisputeService().listMine()); await _cases; }, child: ListView(
        physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(20), children: [
          const Text('Soporte actúa como intermediario. Compartí tu versión con respeto; no confrontes a la otra persona ni compartas códigos o contraseñas.'), const SizedBox(height: 16),
          if (snapshot.hasError) ...[const Text('No pudimos cargar tus reclamos.'), TextButton(onPressed: () => setState(() => _cases = PaymentDisputeService().listMine()), child: const Text('REINTENTAR'))]
          else if (snapshot.data?.isEmpty ?? true) const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: Text('No tenés reclamos de pago.')))
          else for (final item in snapshot.data!) Card(margin: const EdgeInsets.only(bottom: 12), child: ListTile(
            leading: const Icon(Icons.support_agent_outlined), title: Text(TariffService.formatearMonto((item['amount'] as num?)?.toDouble() ?? 0)),
            subtitle: Text(_status(item['status']?.toString())), trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => _CaseScreen(dispute: item))),
          )),
        ],
      ));
    }),
  );
}
String _status(String? value) => switch (value) {
  'resolved_paid' || 'paid' => 'Resuelto: pago recibido',
  'resolved_waived' || 'waived' => 'Resuelto: deuda anulada',
  'unpaid' => 'Pago pendiente', _ => 'En revisión por soporte',
};
class _CaseScreen extends StatefulWidget {
  const _CaseScreen({required this.dispute});
  final Map<String, dynamic> dispute;
  @override
  State<_CaseScreen> createState() => _CaseScreenState();
}
class _CaseScreenState extends State<_CaseScreen> {
  final _message = TextEditingController();
  late Future<List<Map<String, dynamic>>> _messages;
  bool _sending = false;
  String? _error;
  String get _id => widget.dispute['id'].toString();
  @override
  void initState() { super.initState(); _messages = PaymentDisputeService().messages(_id); }
  @override
  void dispose() { _message.dispose(); super.dispose(); }
  Future<void> _send() async {
    final text = _message.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() { _sending = true; _error = null; });
    try {
      await PaymentDisputeService().sendMessage(_id, text);
      if (!mounted) return;
      _message.clear(); setState(() => _messages = PaymentDisputeService().messages(_id));
    } catch (_) { if (mounted) setState(() => _error = 'No se envió el mensaje. Conservamos el texto para que reintentes.'); }
    finally { if (mounted) setState(() => _sending = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Detalle del reclamo'), actions: [IconButton(tooltip: 'Actualizar mensajes', onPressed: () => setState(() => _messages = PaymentDisputeService().messages(_id)), icon: const Icon(Icons.refresh))]),
    body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720), child: ListView(padding: const EdgeInsets.all(20), children: [
      Text(_status(widget.dispute['status']?.toString()), style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 8),
      SelectableText('Reclamo: $_id'), Text('Importe: ${TariffService.formatearMonto((widget.dispute['amount'] as num?)?.toDouble() ?? 0)}'),
      if (widget.dispute['driver_notes']?.toString().isNotEmpty == true) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text('Declaración inicial del conductor: ${widget.dispute['driver_notes']}')),
      if (widget.dispute['resolution_notes']?.toString().isNotEmpty == true) Card(child: Padding(padding: const EdgeInsets.all(16), child: Text('Resolución de soporte: ${widget.dispute['resolution_notes']}'))),
      const Divider(), const Text('Mensajes del expediente', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)), const SizedBox(height: 8),
      const Text('Estos mensajes quedan registrados en el reclamo y pueden verlos soporte y las partes del viaje.'),
      FutureBuilder<List<Map<String, dynamic>>>(future: _messages, builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
        if (snapshot.hasError) return const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Text('No pudimos cargar los mensajes. Usá actualizar para reintentar.'));
        return Column(children: [for (final message in snapshot.data ?? <Map<String, dynamic>>[]) Card(margin: const EdgeInsets.symmetric(vertical: 6), child: ListTile(
          title: Text(switch(message['author_role']) { 'admin' => 'Soporte', 'driver' => 'Conductor', _ => 'Pasajero' }), subtitle: Text(message['body']?.toString() ?? ''),
        ))]);
      }), const SizedBox(height: 16),
      TextField(controller: _message, maxLength: 1500, minLines: 2, maxLines: 5, enabled: !_sending, decoration: const InputDecoration(labelText: 'Tu mensaje para la mediación', hintText: 'Explicá qué ocurrió o aportá información sobre el pago')),
      if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)), const SizedBox(height: 12),
      FilledButton.icon(onPressed: _sending ? null : _send, icon: const Icon(Icons.send_outlined), label: Text(_sending ? 'ENVIANDO…' : 'ENVIAR A SOPORTE')),
    ]))),
  );
}
