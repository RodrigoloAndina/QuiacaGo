import 'package:flutter/foundation.dart';

class DriverSessionService extends ChangeNotifier {
  static final DriverSessionService _instance = DriverSessionService._internal();
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
    notifyListeners();
  }
}
