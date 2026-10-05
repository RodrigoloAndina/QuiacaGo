import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'supabase_service.dart';

class DriverSessionService extends ChangeNotifier {
  static final DriverSessionService _instance =
      DriverSessionService._internal();
  factory DriverSessionService() => _instance;
  DriverSessionService._internal();

  String _id = '';
  String _fullName = 'Conductor Habilitado';
  String _phone = '';
  String _vehicleInfo = 'Taxi Habilitado';
  String _plate = '';
  String _taxiNumber = '';
  String? _approvedUntil;

  String get id => _id;
  String get fullName => _fullName;
  String get phone => _phone;
  String get vehicleInfo => _vehicleInfo;
  String get plate => _plate;
  String get taxiNumber => _taxiNumber;
  String? get approvedUntil => _approvedUntil;

  void setSession({
    required String id,
    required String fullName,
    required String phone,
    required String vehicleInfo,
    required String plate,
    required String taxiNumber,
    String? approvedUntil,
  }) {
    _id = id;
    _fullName = fullName.isNotEmpty ? fullName : 'Conductor Habilitado';
    _phone = phone;
    _vehicleInfo = vehicleInfo.isNotEmpty ? vehicleInfo : 'Taxi Habilitado';
    _plate = plate;
    _taxiNumber = taxiNumber;
    _approvedUntil = approvedUntil;
    unawaited(_persist());
    notifyListeners();
  }

  Future<File> _sessionFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/quiacago_driver_session.json');
  }

  Future<void> _persist() async {
    if (kIsWeb) return;
    final file = await _sessionFile();
    await file.writeAsString(
      jsonEncode({
        'id': _id,
        'full_name': _fullName,
        'phone': _phone,
        'vehicle_info': _vehicleInfo,
        'plate': _plate,
        'taxi_number': _taxiNumber,
        'approved_until': _approvedUntil,
      }),
      flush: true,
    );
  }

  Future<bool> restore() async {
    try {
      if (kIsWeb) return false;
      final file = await _sessionFile();
      if (!await file.exists()) return false;
      final data = Map<String, dynamic>.from(
          jsonDecode(await file.readAsString()) as Map);
      if (data['id'] != SupabaseService().client.auth.currentUser?.id) return false;
      _id = data['id']?.toString() ?? '';
      _fullName = data['full_name']?.toString() ?? 'Conductor Habilitado';
      _phone = data['phone']?.toString() ?? '';
      _vehicleInfo = data['vehicle_info']?.toString() ?? 'Taxi Habilitado';
      _plate = data['plate']?.toString() ?? '';
      _taxiNumber = data['taxi_number']?.toString() ?? '';
      _approvedUntil = data['approved_until']?.toString();
      notifyListeners();
      return _id.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void clear() {
    _id = '';
    _fullName = 'Conductor Habilitado';
    _phone = '';
    _vehicleInfo = 'Taxi Habilitado';
    _plate = '';
    _taxiNumber = '';
    _approvedUntil = null;
    unawaited(_deletePersisted());
    notifyListeners();
  }

  Future<void> _deletePersisted() async {
    if (kIsWeb) return;
    final file = await _sessionFile();
    if (await file.exists()) await file.delete();
  }
}
