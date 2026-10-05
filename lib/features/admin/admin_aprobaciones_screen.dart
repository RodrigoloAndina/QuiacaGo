import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/driver_document_service.dart';
import '../../services/driver_document_rules.dart';
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
  String _query = '';
  String _filter = 'pending';
  String? _reviewingDriverId;

  @override
  void initState() {
    super.initState();
    _restoreAdmin();
  }

  Future<void> _restoreAdmin() async {
    try {
      final profile = await AuthService().currentProfile();
      if (profile?['role'] == 'admin') {
        _authenticated = true;
        await _load();
      }
    } catch (_) {
      // Se muestra el formulario de ingreso si no hay conexión o sesión válida.
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
    if (mounted)
      setState(() {
        _loading = true;
        _error = null;
      });
    try {
      final responses = await Future.wait([
        SupabaseService()
            .client
            .from('profiles')
            .select()
            .eq('role', 'driver')
            .order('created_at'),
        SupabaseService()
            .client
            .from('driver_documents')
            .select()
            .order('created_at'),
      ]);
      _documentsByDriver.clear();
      for (final raw in List<Map<String, dynamic>>.from(responses[1])) {
        final driverId = raw['driver_id'].toString();
        _documentsByDriver.putIfAbsent(driverId, () => []).add(raw);
      }
      if (mounted) {
        setState(
            () => _drivers = List<Map<String, dynamic>>.from(responses[0]));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'No se pudo actualizar el padrón. Revisá la conexión e intentá nuevamente.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setApproval(Map<String, dynamic> driver, bool approved) async {
    final driverId = driver['id'].toString();
    final name = driver['full_name']?.toString() ?? 'el conductor';
    final documents = _documentsByDriver[driverId] ?? const [];
    final summary = DriverDocumentRules.summarize(documents);
    if (approved && !summary.canBeApproved) {
      _showMessage(summary.missing.isNotEmpty
          ? 'Faltan ${summary.missing.length} documentos obligatorios.'
          : 'Hay documentos vencidos o sin fecha válida.');
      return;
    }
    final message = await _reviewMessage(name, approved);
    if (message == null) return;
    if (mounted) setState(() => _reviewingDriverId = driverId);
    try {
      await SupabaseService().client.rpc('review_driver_and_notify', params: {
        'p_driver_id': driverId,
        'p_approved': approved,
        'p_days': 60,
        'p_title': approved ? 'Legajo aprobado' : 'Legajo observado',
        'p_message': message,
      });
      await _load();
      _showMessage(
          approved
              ? '$name quedó habilitado por 60 días.'
              : '$name quedó inhabilitado y recibió la observación.',
          success: approved);
    } catch (e) {
      _showMessage('No se pudo actualizar el conductor. Intentá nuevamente.');
    } finally {
      if (mounted) setState(() => _reviewingDriverId = null);
    }
  }

  Future<void> _openDocument(Map<String, dynamic> document) async {
    try {
      final url = await DriverDocumentService()
          .signedUrl(document['storage_path'].toString());
      final opened =
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!opened) throw StateError('No se pudo abrir');
    } catch (_) {
      _showMessage('No se pudo abrir el documento.');
    }
  }

  void _showMessage(String message, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: success ? AppColors.statusAvailable : null,
    ));
  }

  Future<String?> _reviewMessage(String name, bool approved) async {
    final controller = TextEditingController(
      text: approved
          ? 'Tu legajo fue aprobado. Ya podés trabajar en QuiacaGo durante los próximos 60 días.'
          : '',
    );
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(approved ? 'Aprobar a $name' : 'Observar legajo de $name'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(approved
              ? 'Se aprobarán los cinco documentos y se habilitará al conductor.'
              : 'Explicá qué debe corregir para que pueda resolverlo sin demoras.'),
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              labelText:
                  approved ? 'Mensaje al conductor' : 'Motivo obligatorio',
            ),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCELAR')),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isEmpty) return;
              Navigator.pop(context, controller.text.trim());
            },
            child: Text(approved ? 'APROBAR' : 'ENVIAR OBSERVACIÓN'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  List<Map<String, dynamic>> get _visibleDrivers {
    final normalizedQuery = _query.trim().toLowerCase();
    return _drivers.where((driver) {
      final id = driver['id'].toString();
      final documents = _documentsByDriver[id] ?? const [];
      final summary = DriverDocumentRules.summarize(documents);
      final approved = driver['is_approved'] == true;
      final matchesQuery = normalizedQuery.isEmpty ||
          [
            driver['full_name'],
            driver['phone'],
            driver['plate'],
            driver['taxi_number']
          ].whereType<Object>().any((value) =>
              value.toString().toLowerCase().contains(normalizedQuery));
      final matchesFilter = switch (_filter) {
        'approved' => approved,
        'issues' => summary.missing.isNotEmpty ||
            summary.expired.isNotEmpty ||
            summary.rejected.isNotEmpty,
        'all' => true,
        _ => !approved,
      };
      return matchesQuery && matchesFilter;
    }).toList();
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
    final visibleDrivers = _visibleDrivers;
    return Scaffold(
      appBar: AppBar(title: const Text('Conductores municipales'), actions: [
        IconButton(
            tooltip: 'Actualizar',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh)),
        IconButton(
          tooltip: 'Cerrar sesión',
          onPressed: () async {
            await AuthService().logout();
            if (mounted)
              setState(() {
                _authenticated = false;
                _drivers = [];
              });
          },
          icon: const Icon(Icons.logout),
        ),
      ]),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            onChanged: (value) => setState(() => _query = value),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'Buscar por nombre, teléfono, patente o móvil',
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            _filterChip('pending', 'Pendientes'),
            _filterChip('issues', 'Con observaciones'),
            _filterChip('approved', 'Habilitados'),
            _filterChip('all', 'Todos'),
          ]),
        ),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: _error != null
              ? _adminErrorState()
              : visibleDrivers.isEmpty
                  ? Center(
                      child: Text(_drivers.isEmpty
                          ? 'No hay conductores registrados.'
                          : 'No hay conductores para este filtro.'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: visibleDrivers.length,
                          itemBuilder: (context, index) {
                            final d = visibleDrivers[index];
                            final approved = d['is_approved'] == true;
                            final documents =
                                _documentsByDriver[d['id'].toString()] ??
                                    const [];
                            final summary =
                                DriverDocumentRules.summarize(documents);
                            final reviewing =
                                _reviewingDriverId == d['id'].toString();
                            return Card(
                              child: ExpansionTile(
                                leading: CircleAvatar(
                                  backgroundColor: approved
                                      ? AppColors.statusAvailable
                                      : AppColors.statusPending,
                                  foregroundColor: Colors.white,
                                  child: Text((d['full_name'] ?? 'C')
                                      .toString()[0]
                                      .toUpperCase()),
                                ),
                                title: Text(
                                    d['full_name']?.toString() ?? 'Conductor'),
                                subtitle: Text(
                                    '${approved ? 'Habilitado' : 'Pendiente'} · ${d['plate'] ?? 'Sin patente'} · ${documents.length}/5 documentos'),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 0, 16, 10),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(d['phone']?.toString() ??
                                              'Sin teléfono'),
                                          const SizedBox(height: 4),
                                          Text(d['vehicle_info']?.toString() ??
                                              'Vehículo pendiente'),
                                          const SizedBox(height: 8),
                                          _summaryLine(summary),
                                        ]),
                                  ),
                                  for (final definition
                                      in DriverDocumentRules.definitions)
                                    Builder(builder: (context) {
                                      final document = documents
                                          .cast<Map<String, dynamic>?>()
                                          .firstWhere(
                                            (item) =>
                                                item?['document_type'] ==
                                                definition.type,
                                            orElse: () => null,
                                          );
                                      if (document == null) {
                                        return ListTile(
                                          dense: true,
                                          leading: const Icon(
                                              Icons.error_outline,
                                              color: AppColors.statusRejected),
                                          title: Text(definition.label),
                                          subtitle: const Text('Falta cargar'),
                                        );
                                      }
                                      final status =
                                          document['status']?.toString() ??
                                              'pending';
                                      return ListTile(
                                        dense: true,
                                        leading: Icon(_statusIcon(status),
                                            color: _statusColor(status)),
                                        title: Text(definition.label),
                                        subtitle: Text(
                                            '${_statusLabel(status)}${definition.requiresExpiry ? ' · Vence: ${document['expires_at'] ?? 'Sin fecha'}' : ''}'),
                                        trailing: IconButton(
                                          tooltip: 'Abrir documento',
                                          onPressed: () =>
                                              _openDocument(document),
                                          icon: const Icon(Icons.open_in_new),
                                        ),
                                      );
                                    }),
                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          if (reviewing)
                                            const Padding(
                                              padding: EdgeInsets.all(10),
                                              child: SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child:
                                                      CircularProgressIndicator(
                                                          strokeWidth: 2)),
                                            )
                                          else if (approved)
                                            OutlinedButton.icon(
                                                onPressed: () =>
                                                    _setApproval(d, false),
                                                icon: const Icon(
                                                    Icons.block_outlined),
                                                label: const Text('OBSERVAR'))
                                          else ...[
                                            OutlinedButton(
                                                onPressed: () =>
                                                    _setApproval(d, false),
                                                child: const Text('OBSERVAR')),
                                            const SizedBox(width: 8),
                                            ElevatedButton.icon(
                                                onPressed: summary.canBeApproved
                                                    ? () =>
                                                        _setApproval(d, true)
                                                    : null,
                                                icon: const Icon(
                                                    Icons.verified_outlined),
                                                label: const Text('APROBAR')),
                                          ],
                                        ]),
                                  ),
                                ],
                              ),
                            );
                          })),
        ),
      ]),
    );
  }

  Widget _filterChip(String value, String label) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: _filter == value,
          onSelected: (_) => setState(() => _filter = value),
        ),
      );

  Widget _summaryLine(DriverDocumentSummary summary) {
    final (text, color) = summary.missing.isNotEmpty
        ? (
            'Faltan ${summary.missing.length} documentos',
            AppColors.statusRejected
          )
        : summary.expired.isNotEmpty
            ? ('Hay documentación vencida', AppColors.statusRejected)
            : summary.rejected.isNotEmpty
                ? ('Hay documentos observados', AppColors.statusRejected)
                : summary.pending.isNotEmpty
                    ? (
                        'Legajo completo, pendiente de revisión',
                        AppColors.statusPending
                      )
                    : ('Legajo completo y vigente', AppColors.statusAvailable);
    return Text(text,
        style: TextStyle(color: color, fontWeight: FontWeight.w700));
  }

  String _statusLabel(String status) => switch (status) {
        'approved' => 'Aprobado',
        'rejected' => 'Observado',
        'expired' => 'Vencido',
        _ => 'Pendiente',
      };

  Color _statusColor(String status) => switch (status) {
        'approved' => AppColors.statusAvailable,
        'rejected' || 'expired' => AppColors.statusRejected,
        _ => AppColors.statusPending,
      };

  IconData _statusIcon(String status) => switch (status) {
        'approved' => Icons.check_circle_outline,
        'rejected' || 'expired' => Icons.error_outline,
        _ => Icons.hourglass_top_outlined,
      };

  Widget _adminErrorState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_outlined, size: 48),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('REINTENTAR')),
          ]),
        ),
      );
}
