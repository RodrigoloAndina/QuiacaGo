import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';
import 'driver_document_rules.dart';

class DriverDocumentService {
  SupabaseClient get _client => SupabaseService().client;

  Future<void> upload({
    required String driverId,
    required String type,
    required String dataUri,
    required String fileName,
    DateTime? expiresAt,
  }) async {
    final comma = dataUri.indexOf(',');
    if (comma < 0) throw const FormatException('Archivo inválido');
    final bytes =
        Uint8List.fromList(base64Decode(dataUri.substring(comma + 1)));
    final validationError =
        DriverDocumentRules.validateUpload(fileName, bytes.length);
    if (validationError != null) throw FormatException(validationError);
    final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final extension = DriverDocumentRules.extensionOf(safeName);
    final path = '$driverId/$type.$extension';

    await _client.storage.from('driver-documents').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: DriverDocumentRules.contentTypeFor(safeName),
          ),
        );

    final existing = await _client
        .from('driver_documents')
        .select('id')
        .eq('driver_id', driverId)
        .eq('document_type', type)
        .maybeSingle();
    final values = {
      'storage_path': path,
      'expires_at': expiresAt?.toIso8601String().split('T').first,
    };
    if (existing == null) {
      await _client.from('driver_documents').insert({
        'driver_id': driverId,
        'document_type': type,
        ...values,
      });
    } else {
      await _client
          .from('driver_documents')
          .update(values)
          .eq('id', existing['id']);
    }
  }

  Future<List<Map<String, dynamic>>> forDriver(String driverId) async {
    final rows = await _client
        .from('driver_documents')
        .select()
        .eq('driver_id', driverId)
        .order('created_at');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<String> signedUrl(String storagePath) => _client.storage
      .from('driver-documents')
      .createSignedUrl(storagePath, 300);
}
