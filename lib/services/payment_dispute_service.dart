import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

class PaymentDisputeService {
  SupabaseClient get _client => SupabaseService().client;

  Future<List<Map<String, dynamic>>> listMine() async => _rows(
      await _client.rpc('get_my_payment_disputes'));

  Future<List<Map<String, dynamic>>> messages(String disputeId) async => _rows(
      await _client.rpc('get_payment_dispute_messages', params: {'p_dispute_id': disputeId}));

  Future<void> sendMessage(String disputeId, String message) async {
    await _client.rpc('add_payment_dispute_message', params: {
      'p_dispute_id': disputeId, 'p_message': message.trim(),
    });
  }

  List<Map<String, dynamic>> _rows(dynamic data) =>
      (data as List).map((row) => Map<String, dynamic>.from(row as Map)).toList();

  Future<Map<String, dynamic>?> myOpenDispute() async {
    final rows = await _client.rpc('get_my_open_payment_dispute');
    if (rows is List && rows.isNotEmpty) {
      return Map<String, dynamic>.from(rows.first as Map);
    }
    return null;
  }
}
