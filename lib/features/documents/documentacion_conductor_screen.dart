import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../services/driver_document_service.dart';
import '../../services/driver_document_rules.dart';
import '../../services/supabase_service.dart';

class DocumentacionConductorScreen extends StatefulWidget {
  const DocumentacionConductorScreen({super.key});

  @override
  State<DocumentacionConductorScreen> createState() =>
      _DocumentacionConductorScreenState();
}

class _DocumentacionConductorScreenState
    extends State<DocumentacionConductorScreen> {
  final _service = DriverDocumentService();
  List<Map<String, dynamic>> _documents = [];
  bool _loading = true;
  String? _uploadingType;
  String? _loadError;

  String get _driverId => SupabaseService().client.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_driverId.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    if (mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    try {
      final documents = await _service.forDriver(_driverId);
      if (mounted) setState(() => _documents = documents);
    } catch (_) {
      if (mounted) {
        setState(() => _loadError =
            'No pudimos consultar tu legajo. Revisá la conexión e intentá nuevamente.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic>? _documentFor(String type) {
    for (final document in _documents) {
      if (document['document_type'] == type) return document;
    }
    return null;
  }

  Future<DateTime?> _expiryFor(String type) async {
    if (type == 'dni_front' || type == 'dni_back') return null;
    final now = DateTime.now();
    final currentExpiry =
        DateTime.tryParse(_documentFor(type)?['expires_at']?.toString() ?? '');
    final initialDate = currentExpiry != null && currentExpiry.isAfter(now)
        ? currentExpiry
        : now.add(const Duration(days: 365));
    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: DateTime(now.year + 10),
      helpText: 'Seleccioná el vencimiento del documento',
    );
  }

  Future<void> _upload(String type) async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
    );
    if (files.isEmpty) return;
    final file = files.first;
    final fileLength = await file.length() ?? 0;
    final validationError =
        DriverDocumentRules.validateUpload(file.name, fileLength);
    if (validationError != null) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(validationError)));
      }
      return;
    }
    final current = _documentFor(type);
    if (current != null && mounted) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('¿Actualizar este documento?'),
          content: const Text(
              'La versión actual será reemplazada y el legajo volverá a revisión administrativa.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('CANCELAR')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('ACTUALIZAR')),
          ],
        ),
      );
      if (replace != true) return;
    }
    final bytes = await file.readAsBytes();
    final expiry = await _expiryFor(type);
    if (type != 'dni_front' && type != 'dni_back' && expiry == null) return;

    setState(() => _uploadingType = type);
    try {
      final mime = DriverDocumentRules.contentTypeFor(file.name);
      await _service.upload(
        driverId: _driverId,
        type: type,
        dataUri: 'data:$mime;base64,${base64Encode(bytes)}',
        fileName: file.name,
        expiresAt: expiry,
      );
      final profileField = {
        'license': 'licencia_expiration',
        'insurance': 'seguro_expiration',
        'vtv': 'vtv_expiration',
      }[type];
      if (profileField != null && expiry != null) {
        await SupabaseService().client.from('profiles').update({
          profileField: expiry.toIso8601String().split('T').first,
        }).eq('id', _driverId);
      }
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Documento guardado y enviado a revisión.'),
        ));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo subir el documento: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingType = null);
    }
  }

  Future<void> _open(Map<String, dynamic> document) async {
    try {
      final url = await _service.signedUrl(document['storage_path'].toString());
      final opened =
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!opened) throw StateError('No hay una aplicación disponible.');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No pudimos abrir el documento. Intentá nuevamente.'),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Mi legajo de conductor'),
        backgroundColor: AppColors.primary,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _driverId.isEmpty
              ? const Center(
                  child: Text('Iniciá sesión para cargar tu legajo.'))
              : _loadError != null
                  ? _errorState()
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          _summaryCard(),
                          const SizedBox(height: 16),
                          for (final definition
                              in DriverDocumentRules.definitions)
                            _documentCard(definition.type, definition.label),
                        ],
                      ),
                    ),
    );
  }

  Widget _documentCard(String type, String title) {
    final document = _documentFor(type);
    final status = document?['status']?.toString() ?? 'missing';
    final expiry = DateTime.tryParse(document?['expires_at']?.toString() ?? '');
    final daysUntilExpiry = DriverDocumentRules.daysUntilExpiry(expiry);
    final expiresSoon = daysUntilExpiry != null &&
        daysUntilExpiry >= 0 &&
        daysUntilExpiry <= 30;
    final isExpired = daysUntilExpiry != null && daysUntilExpiry < 0;
    final needsExpiryAttention =
        (expiresSoon || isExpired) && status == 'approved';
    final color = switch (status) {
      'approved' => AppColors.statusAvailable,
      'rejected' || 'expired' => AppColors.statusRejected,
      _ => AppColors.statusPending,
    };
    final statusLabel = switch (status) {
      'approved' => 'APROBADO',
      'rejected' => 'RECHAZADO',
      'expired' => 'VENCIDO',
      'pending' => 'EN REVISIÓN',
      _ => 'FALTA CARGAR',
    };
    final label = needsExpiryAttention
        ? (daysUntilExpiry < 0 ? 'VENCIDO' : 'VENCE PRONTO')
        : statusLabel;
    final displayColor = needsExpiryAttention
        ? (daysUntilExpiry < 0
            ? AppColors.statusRejected
            : AppColors.statusPending)
        : color;
    final expiryText = document?['expires_at']?.toString();
    final reviewNote = document?['review_note']?.toString().trim();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.description_outlined, color: displayColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              Text(label,
                  style: TextStyle(
                      color: displayColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ]),
            if (expiryText != null) ...[
              const SizedBox(height: 6),
              Text(
                  daysUntilExpiry != null
                      ? 'Vence: $expiryText · ${daysUntilExpiry < 0 ? 'vencido' : 'faltan $daysUntilExpiry días'}'
                      : 'Vence: $expiryText',
                  style: const TextStyle(color: AppColors.textSecondary)),
            ],
            if (reviewNote?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('Observación: $reviewNote',
                    style: const TextStyle(
                        color: AppColors.statusRejected,
                        fontWeight: FontWeight.w600)),
              ),
            ],
            const SizedBox(height: 10),
            Row(children: [
              if (document != null)
                TextButton.icon(
                  onPressed: () => _open(document),
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('VER'),
                ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _uploadingType == null ? () => _upload(type) : null,
                icon: _uploadingType == type
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.upload_file_outlined),
                label: Text(document == null ? 'CARGAR' : 'ACTUALIZAR'),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard() {
    final summary = DriverDocumentRules.summarize(_documents);
    final uploaded =
        DriverDocumentRules.definitions.length - summary.missing.length;
    String message;
    Color color;
    IconData icon;
    if (summary.missing.isNotEmpty) {
      message =
          'Te faltan ${summary.missing.length} documentos para completar el legajo.';
      color = AppColors.statusRejected;
      icon = Icons.pending_actions_outlined;
    } else if (summary.expired.isNotEmpty) {
      message = 'Tenés documentación vencida o sin fecha válida.';
      color = AppColors.statusRejected;
      icon = Icons.event_busy_outlined;
    } else if (summary.rejected.isNotEmpty) {
      message =
          'Administración pidió reemplazar ${summary.rejected.length} documento(s).';
      color = AppColors.statusRejected;
      icon = Icons.error_outline;
    } else if (summary.pending.isNotEmpty) {
      message = 'Tu legajo está completo y espera revisión administrativa.';
      color = AppColors.statusPending;
      icon = Icons.hourglass_top_outlined;
    } else {
      message = 'Tu documentación está completa, vigente y aprobada.';
      color = AppColors.statusAvailable;
      icon = Icons.verified_outlined;
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Expanded(
                child: Text(message,
                    style:
                        TextStyle(color: color, fontWeight: FontWeight.w800))),
          ]),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: uploaded / DriverDocumentRules.definitions.length,
            minHeight: 7,
            borderRadius: BorderRadius.circular(10),
          ),
          const SizedBox(height: 8),
          Text(
              '$uploaded de ${DriverDocumentRules.definitions.length} documentos cargados',
              style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          const Text(
            'Formatos admitidos: JPG, PNG o PDF, hasta 10 MB. Al reemplazar un archivo, vuelve a revisión.',
            style: TextStyle(color: AppColors.textSecondary, height: 1.35),
          ),
        ]),
      ),
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off_outlined,
              size: 52, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          Text(_loadError!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('REINTENTAR'),
          ),
        ]),
      ),
    );
  }
}
