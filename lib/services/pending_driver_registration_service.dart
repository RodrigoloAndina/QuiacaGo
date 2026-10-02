import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'driver_document_service.dart';

class PendingDriverDocument {
  final String type;
  final String dataUri;
  final String fileName;
  final DateTime? expiresAt;

  const PendingDriverDocument({
    required this.type,
    required this.dataUri,
    required this.fileName,
    this.expiresAt,
  });
}

class PendingDriverRegistrationService {
  Future<Directory> _directory(String userId) async {
    final root = await getApplicationSupportDirectory();
    return Directory('${root.path}/pending-driver-registration/$userId');
  }

  Future<void> save(
      String userId, List<PendingDriverDocument> documents) async {
    if (documents.isEmpty) return;
    final directory = await _directory(userId);
    if (await directory.exists()) await directory.delete(recursive: true);
    await directory.create(recursive: true);
    final manifest = <Map<String, dynamic>>[];
    for (var index = 0; index < documents.length; index++) {
      final document = documents[index];
      final comma = document.dataUri.indexOf(',');
      if (comma < 0) continue;
      final mime = document.dataUri.substring(5, comma).split(';').first;
      final file = File('${directory.path}/document-$index.bin');
      await file.writeAsBytes(
          base64Decode(document.dataUri.substring(comma + 1)),
          flush: true);
      manifest.add({
        'type': document.type,
        'path': file.path,
        'file_name': document.fileName,
        'mime': mime,
        'expires_at': document.expiresAt?.toIso8601String(),
      });
    }
    await File('${directory.path}/manifest.json')
        .writeAsString(jsonEncode(manifest), flush: true);
  }

  Future<bool> uploadIfPresent(String userId) async {
    final directory = await _directory(userId);
    final manifestFile = File('${directory.path}/manifest.json');
    if (!await manifestFile.exists()) return false;
    final entries = List<Map<String, dynamic>>.from(
        jsonDecode(await manifestFile.readAsString()) as List);
    final service = DriverDocumentService();
    for (final entry in entries) {
      final file = File(entry['path'].toString());
      if (!await file.exists()) continue;
      await service.upload(
        driverId: userId,
        type: entry['type'].toString(),
        dataUri:
            'data:${entry['mime']};base64,${base64Encode(await file.readAsBytes())}',
        fileName: entry['file_name'].toString(),
        expiresAt: DateTime.tryParse(entry['expires_at']?.toString() ?? ''),
      );
    }
    await directory.delete(recursive: true);
    return true;
  }
}
