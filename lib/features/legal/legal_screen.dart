import 'package:flutter/material.dart';
import '../../services/legal_service.dart';

class LegalScreen extends StatefulWidget {
  const LegalScreen({super.key, this.requireAcceptance = false, this.onAccepted});
  final bool requireAcceptance;
  final VoidCallback? onAccepted;
  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> {
  late Future<List<Map<String, dynamic>>> _documents;
  bool _agreed = false;
  bool _saving = false;
  String? _error;
  @override
  void initState() { super.initState(); _documents = LegalService().documents(); }
  Future<void> _accept() async {
    if (!_agreed || _saving) return;
    setState(() { _saving = true; _error = null; });
    try {
      await LegalService().acceptCurrentDocuments();
      if (mounted) widget.onAccepted?.call();
    } catch (_) {
      if (mounted) setState(() => _error = 'No pudimos registrar tu aceptación. Revisá la conexión y reintentá.');
    } finally { if (mounted) setState(() => _saving = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Condiciones y privacidad'), automaticallyImplyLeading: !widget.requireAcceptance),
    body: FutureBuilder<List<Map<String, dynamic>>>(future: _documents, builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
      if (snapshot.hasError || snapshot.data == null || snapshot.data!.isEmpty) {
        return Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('No pudimos cargar las condiciones del servicio.'), const SizedBox(height: 16),
          FilledButton(onPressed: () => setState(() => _documents = LegalService().documents()), child: const Text('REINTENTAR')),
        ])));
      }
      return Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720), child: ListView(padding: const EdgeInsets.all(20), children: [
        const Text('Conocé cómo funciona QuiacaGo, cómo usamos tus datos y cómo ejercer tus derechos.', style: TextStyle(fontSize: 16, height: 1.5)), const SizedBox(height: 16),
        for (final document in snapshot.data!) Card(margin: const EdgeInsets.only(bottom: 12), child: ExpansionTile(
          title: Text(document['title']?.toString() ?? 'Documento'), subtitle: Text('Versión ${document['version'] ?? LegalService.version}'),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          children: [SelectableText(document['content']?.toString() ?? '', style: const TextStyle(height: 1.5))],
        )),
        if (widget.requireAcceptance) ...[
          CheckboxListTile(value: _agreed, controlAffinity: ListTileControlAffinity.leading, contentPadding: EdgeInsets.zero,
            title: const Text('Leí y acepto los términos del servicio y fui informado sobre el tratamiento de mis datos.'), onChanged: _saving ? null : (value) => setState(() => _agreed = value ?? false)),
          if (_error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
          FilledButton(onPressed: _agreed && !_saving ? _accept : null, child: Text(_saving ? 'GUARDANDO…' : 'ACEPTAR Y CONTINUAR')),
        ], const SizedBox(height: 24),
      ])));
    }),
  );
}
