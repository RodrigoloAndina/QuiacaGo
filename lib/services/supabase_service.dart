import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();

  factory SupabaseService() => _instance;

  SupabaseService._internal();

  // URL de Proyecto Supabase para QuiacaGo
  static const String supabaseUrl = 'https://xxqumxhdpjtjdcnnjmdm.supabase.co';

  // Anon Key JWT oficial (reemplaza la key legacy anterior que no funcionaba)
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh4cXVteGhkcGp0amRjbm5qbWRtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ1MjQ4NjgsImV4cCI6MjEwMDEwMDg2OH0.1L-wFBgeQHcTQIsBQWCFMUffjaaW1jRNfGQR7S_OOeI';

  Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }

  SupabaseClient get client => Supabase.instance.client;
}
