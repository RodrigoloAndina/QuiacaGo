import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/driver_document_service.dart';
import '../../services/supabase_service.dart';

class AdminAprobacionesScreen extends StatefulWidget {
  const AdminAprobacionesScreen({super.key});
  @override
  State<AdminAprobacionesScreen> createState() =>
      _AdminAprobacionesScreenState();
}

class _AdminAprobacionesScreenState extends State<AdminAprobacionesScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  List<Map<String, dynamic>> _drivers = [];
  final Map<String, List<Map<String, dynamic>>> _documentsByDriver = {};
  bool _authenticated = false;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _restoreAdmin();
  }

  Future<void> _restoreAdmin() async {
    final profile = await AuthService().currentProfile();
    if (profile?['role'] == 'admin') {
      _authenticated = true;
      await _load();
    }
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = AuthService();
      await auth.signIn(
          identifier: _email.text.trim(), password: _password.text);
      final profile = await auth.currentProfile();
      if (profile?['role'] != 'admin') {
        await auth.logout();
        throw StateError('La cuenta no tiene permisos de administrador.');
      }
      _authenticated = true;
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _load() async {
    final rows = await SupabaseService()
        .client
        .from('profiles')
        .select()
        .eq('role', 'driver')
        .order('created_at');
    final documents = await SupabaseService()
        .client
        .from('driver_documents')
        .select()
        .order('created_at');
    _documentsByDriver.clear();
    for (final raw in List<Map<String, dynamic>>.from(documents)) {
      final driverId = raw['driver_id'].toString();
      _documentsByDriver.putIfAbsent(driverId, () => []).add(raw);
    }
    if (mounted) {
      setState(() => _drivers = List<Map<String, dynamic>>.from(rows));
    }
  }

  Future<void> _setApproval(Map<String, dynamic> driver, bool approved) async {
    try {
      final driverId = driver['id'].toString();
      final documents = _documentsByDriver[driverId] ?? const [];
      if (approved) {
        const required = {
          'dni_front',
          'dni_back',
          'license',
          'insurance',
          'vtv'
        };
        final present =
            documents.map((d) => d['document_type'].toString()).toSet();
        final expired = documents.any((document) {
          final value = document['expires_at']?.toString();
          final date = value == null ? null : DateTime.tryParse(value);
          return date != null && date.isBefore(DateTime.now());
        });
        if (!present.containsAll(required) || expired) {
          throw StateError(expired
              ? 'Hay documentos vencidos.'
              : 'Faltan documentos obligatorios.');
        }
      }
      await SupabaseService().client.rpc('review_driver', params: {
        'p_driver_id': driverId,
        'p_approved': approved,
        'p_days': 30,
      });
      await _load();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('No se pudo actualizar: $e')));
    }
  }

  Future<void> _openDocument(Map<String, dynamic> document) async {
    final url = await DriverDocumentService()
        .signedUrl(document['storage_path'].toString());
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    if (!_authenticated) {
      return Scaffold(
          appBar: AppBar(title: const Text('Administración QuiacaGo')),
          body: Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.admin_panel_settings,
                            size: 64, color: AppColors.primary),
                        const SizedBox(height: 20),
                        TextField(
                            controller: _email,
                            decoration: const InputDecoration(
                                labelText: 'Correo administrativo')),
                        const SizedBox(height: 12),
                        TextField(
                            controller: _password,
                            obscureText: true,
                            decoration:
                                const InputDecoration(labelText: 'Contraseña')),
                        const SizedBox(height: 16),
                        if (_error != null)
                          Text(_error!,
                              style: const TextStyle(color: Colors.red)),
                        ElevatedButton(
                            onPressed: _loading ? null : _login,
                            child: Text(_loading ? 'INGRESANDO…' : 'INGRESAR')),
                      ])))));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Conductores municipales'), actions: [
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh))
      ]),
      body: _drivers.isEmpty
          ? const Center(child: Text('No hay conductores registrados.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _drivers.length,
              itemBuilder: (context, index) {
                final d = _drivers[index];
                final approved = d['is_approved'] == true;
                final documents =
                    _documentsByDriver[d['id'].toString()] ?? const [];
                return Card(
                  child: ExpansionTile(
                    leading: CircleAvatar(
                        child: Text((d['full_name'] ?? 'C')
                            .toString()[0]
                            .toUpperCase())),
                    title: Text(d['full_name']?.toString() ?? 'Conductor'),
                    subtitle: Text(
                        '${d['phone'] ?? ''} · ${d['plate'] ?? '-'} · ${documents.length}/5 documentos'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(d['vehicle_info']?.toString() ??
                              'Vehículo pendiente'),
                        ),
                      ),
                      for (final document in documents)
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.description_outlined),
                          title: Text(document['document_type'].toString()),
                          subtitle: Text(
                              'Vence: ${document['expires_at'] ?? 'No corresponde'} · ${document['status']}'),
                          trailing: IconButton(
                            tooltip: 'Abrir documento',
                            onPressed: () => _openDocument(document),
                            icon: const Icon(Icons.open_in_new),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: approved
                              ? OutlinedButton(
                                  onPressed: () => _setApproval(d, false),
                                  child: const Text('SUSPENDER'))
                              : ElevatedButton(
                                  onPressed: () => _setApproval(d, true),
                                  child: const Text('APROBAR')),
                        ),
                      ),
                    ],
                  ),
                );
              }),
    );
  }
}
