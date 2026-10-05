import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';
import 'supabase_service.dart';

class AccountService {
  SupabaseClient get _client => SupabaseService().client;

  Future<void> deleteMyAccount({required bool isDriver}) async {
    late FunctionResponse response;
    try {
      response = await _client.functions.invoke('delete-account');
    } on FunctionException catch (error) {
      final details = error.details;
      throw StateError(details is Map && details['error'] is String
          ? details['error'] as String
          : 'No se pudo completar la eliminación. Reintentá o contactá a soporte.');
    }
    if (response.status != 200 ||
        response.data is! Map ||
        response.data['success'] != true) {
      throw StateError('No se confirmó la eliminación. Contactá a soporte.');
    }
    await AuthService().logout();
  }
}
