import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();

  factory SupabaseService() => _instance;

  SupabaseService._internal();

  // URL de Proyecto y Publishable Key Oficial de Supabase para QuiacaGo
  static const String supabaseUrl = 'https://xxqumxhdpjtjdcnnjmdm.supabase.co';
  static const String supabasePublishableKey = 'sb_publishable_OC59lTtwS710LNHbk1mBIA_UlTRguIN';

  Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabasePublishableKey,
    );
  }

  SupabaseClient get client => Supabase.instance.client;
}
