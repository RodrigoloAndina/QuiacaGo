import 'dart:convert';

import 'package:flutter/services.dart';

import 'supabase_service.dart';

class LegalService {
  static const version = '2026-10-04';
  static const operatorName = String.fromEnvironment('LEGAL_OPERATOR',
      defaultValue: 'Responsable pendiente de configurar');
  static const operatorAddress = String.fromEnvironment('LEGAL_ADDRESS',
      defaultValue: 'Domicilio pendiente de configurar');
  static const privacyEmail = String.fromEnvironment('LEGAL_EMAIL',
      defaultValue: 'Correo de privacidad pendiente de configurar');
  static const supportPhone = String.fromEnvironment('LEGAL_PHONE',
      defaultValue: 'Contacto pendiente de configurar');

  Future<List<Map<String, dynamic>>> documents() async {
    final raw = await rootBundle.loadString('assets/legal/documents.json');
    return (jsonDecode(raw) as List).map((item) {
      final document = Map<String, dynamic>.from(item as Map);
      document['content'] = (document['content'] as String)
          .replaceAll('{{operator}}', operatorName)
          .replaceAll('{{address}}', operatorAddress)
          .replaceAll('{{email}}', privacyEmail)
          .replaceAll('{{phone}}', supportPhone);
      return document;
    }).toList();
  }

  Future<bool> needsAcceptance() async {
    final result =
        await SupabaseService().client.rpc('get_my_legal_acceptance');
    return result is! Map ||
        result['accepted'] != true ||
        result['version'] != version;
  }

  Future<void> acceptCurrentDocuments() async {
    await SupabaseService()
        .client
        .rpc('accept_legal_documents', params: {'p_version': version});
  }
}
