import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

class DriverMessageService {
  SupabaseClient get _client => SupabaseService().client;

  Future<List<Map<String, dynamic>>> list({bool unreadOnly = false}) async {
    var query = _client
        .from('driver_messages')
        .select()
        .eq('driver_id', _client.auth.currentUser?.id ?? '')
        .order('created_at', ascending: false)
        .limit(50);
    if (unreadOnly) query = query.isFilter('read_at', null);
    final rows = await query;
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> markRead(String id) async {
    await _client.rpc('mark_driver_message_read', params: {'p_message_id': id});
  }
}
