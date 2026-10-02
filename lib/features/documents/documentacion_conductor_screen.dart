import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../services/driver_document_service.dart';
import '../../services/supabase_service.dart';

class DocumentacionConductorScreen extends StatefulWidget {
  const DocumentacionConductorScreen({super.key});

  @override
  State<DocumentacionConductorScreen> createState() =>
      _DocumentacionConductorScreenState();
}

class _DocumentacionConductorScreenState
    extends State<DocumentacionConductorScreen> {
  static const _types = <String, String>{
    'dni_front': 'DNI frente',
    'dni_back': 'DNI dorso',
    'license': 'Licencia',
    'insurance': 'Póliza de seguro de taxi',
    'vtv': 'VTV / RTO vigente',
  };

  final _service = DriverDocumentService();
  List<Map<String, dynamic>> _documents = [];
  bool _loading = true;
  String? _uploadingType;

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
    try {
      final documents = await _service.forDriver(_driverId);
      if (mounted) setState(() => _documents = documents);
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
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;
    final expiry = await _expiryFor(type);
    if (type != 'dni_front' && type != 'dni_back' && expiry == null) return;

    setState(() => _uploadingType = type);
    try {
      final extension = file.extension?.toLowerCase() ?? 'jpg';
      final mime = extension == 'pdf' ? 'application/pdf' : 'image/$extension';
      await _service.upload(
        driverId: _driverId,
        type: type,
        dataUri: 'data:$mime;base64,${base64Encode(file.bytes!)}',
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
    final url = await _service.signedUrl(document['storage_path'].toString());
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
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
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      const Text(
                        'Cargá los cinco documentos para completar tu legajo. Podés reemplazar licencia, seguro o VTV antes de su vencimiento; la nueva versión quedará pendiente de revisión.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      for (final entry in _types.entries)
                        _documentCard(entry.key, entry.value),
                    ],
                  ),
                ),
    );
  }

  Widget _documentCard(String type, String title) {
    final document = _documentFor(type);
    final status = document?['status']?.toString() ?? 'missing';
    final expiry = DateTime.tryParse(document?['expires_at']?.toString() ?? '');
    final daysUntilExpiry = expiry?.difference(DateTime.now()).inDays;
    final expiresSoon = daysUntilExpiry != null && daysUntilExpiry <= 30;
    final needsExpiryAttention = expiresSoon && status == 'approved';
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
}
