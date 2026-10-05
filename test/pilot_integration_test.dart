import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:quiaca_go_conductor/services/trip_service.dart';
import 'package:quiaca_go_conductor/services/driver_location_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/shared_preferences'),
          (call) async => call.method == 'getAll' ? <String, Object>{} : true);
  const passenger = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  var owner = passenger;
  var codesFail = false;
  var countFail = false;
  final paths = <String>[];
  setUpAll(() async {
    String part(Object v) =>
        base64Url.encode(utf8.encode(jsonEncode(v))).replaceAll('=', '');
    final token = '${part({'alg': 'HS256'})}.${part({
          'sub': passenger,
          'exp': 4102444800
        })}.signature';
    await Supabase.initialize(
        url: 'https://test.invalid',
        publishableKey: 'test-key',
        authOptions: const FlutterAuthClientOptions(
            persistSession: false,
            autoRefreshToken: false,
            detectSessionInUri: false),
        httpClient: MockClient((request) async {
          final path = request.url.path;
          paths.add(path);
          Object? body;
          var status = 200;
          if (path == '/auth/v1/token') {
            body = {
              'access_token': token,
              'refresh_token': 'refresh',
              'token_type': 'bearer',
              'expires_in': 3600,
              'user': {
                'id': passenger,
                'aud': 'authenticated',
                'role': 'authenticated',
                'email': 'test@example.test',
                'app_metadata': {},
                'user_metadata': {},
                'created_at': '2026-01-01T00:00:00Z'
              }
            };
          } else if (path == '/rest/v1/trips') {
            body = [
              {
                'id': 'trip-test',
                'passenger_id': owner,
                'status': 'arrived',
                'pin_code': '0000',
                'finish_code': '0000'
              }
            ];
          } else if (path.endsWith('get_my_trip_codes')) {
            body = codesFail
                ? {'message': 'unavailable'}
                : {'pin_code': '1234', 'finish_code': '5678'};
            status = codesFail ? 403 : 200;
          } else if (path.endsWith('available_driver_count')) {
            body = countFail ? {'message': 'unavailable'} : 3;
            status = countFail ? 403 : 200;
          } else {
            body = {};
          }
          return http.Response(jsonEncode(body), status,
              request: request, headers: {'content-type': 'application/json'});
        }));
    await Supabase.instance.client.auth
        .signInWithPassword(email: 'test@example.test', password: 'test');
  });
  setUp(() {
    paths.clear();
    owner = passenger;
    codesFail = false;
    countFail = false;
  });
  tearDownAll(() async => Supabase.instance.dispose());
  test('passenger receives private codes instead of public placeholders',
      () async {
    final trip = await TripService.obtenerViaje('trip-test');
    expect(trip?.pinCode, '1234');
    expect(trip?.finishCode, '5678');
    expect(paths, contains('/rest/v1/rpc/get_my_trip_codes'));
  });
  test('driver view never requests passenger codes', () async {
    owner = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
    final trip = await TripService.obtenerViaje('trip-test');
    expect(trip?.pinCode, '----');
    expect(paths, isNot(contains('/rest/v1/rpc/get_my_trip_codes')));
  });
  test('failed code lookup preserves trip and retries on refresh', () async {
    codesFail = true;
    expect((await TripService.obtenerViaje('trip-test'))?.pinCode, '----');
    codesFail = false;
    expect((await TripService.obtenerViaje('trip-test'))?.pinCode, '1234');
  });
  test('availability uses aggregate and distinguishes error from zero',
      () async {
    expect(await Supabase.instance.client.rpc('available_driver_count'), 3);
    paths.clear();
    expect(await DriverLocationService.availableCount(), 3);
    expect(paths, ['/rest/v1/rpc/available_driver_count']);
    countFail = true;
    expect(await DriverLocationService.availableCount(), isNull);
  });
}
