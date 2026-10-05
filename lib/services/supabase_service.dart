import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();

  factory SupabaseService() => _instance;

  SupabaseService._internal();

  // Los valores pueden reemplazarse con --dart-define para separar beta y producción.
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://xxqumxhdpjtjdcnnjmdm.supabase.co',
  );

  // Anon Key JWT oficial (reemplaza la key legacy anterior que no funcionaba)
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh4cXVteGhkcGp0amRjbm5qbWRtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ1MjQ4NjgsImV4cCI6MjEwMDEwMDg2OH0.1L-wFBgeQHcTQIsBQWCFMUffjaaW1jRNfGQR7S_OOeI',
  );

  String _appKey = 'unknown_production';
  int _buildNumber = 1;
  bool _isBeta = false;

  String get appKey => _appKey;
  int get buildNumber => _buildNumber;
  bool get isBeta => _isBeta;

  Future<void> initialize({String appType = 'unknown'}) async {
    final package = await PackageInfo.fromPlatform();
    const configuredChannel = String.fromEnvironment('APP_CHANNEL');
    _isBeta = configuredChannel.isNotEmpty
        ? configuredChannel.toLowerCase() == 'beta'
        : package.packageName.toLowerCase().endsWith('.beta');
    _buildNumber = int.tryParse(package.buildNumber) ?? 1;
    _appKey = '${appType}_${_isBeta ? 'beta' : 'production'}';
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseAnonKey,
      headers: {
        'x-quiacago-app': _appKey,
        'x-quiacago-build': _buildNumber.toString(),
      },
    );
  }

  SupabaseClient get client => Supabase.instance.client;
}
