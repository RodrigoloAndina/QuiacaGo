import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/vehicle.dart';
import '../models/document.dart';
import '../models/earning.dart';
import '../core/constants/app_constants.dart';
import '../repositories/driver_repository.dart';

final driverRepositoryProvider = Provider<DriverRepository>((ref) {
  return DriverRepositoryImpl();
});

final driverStatusProvider = StateProvider<DriverStatus>((ref) {
  return DriverStatus.OFFLINE;
});

final driverEarningsProvider = FutureProvider.family<Earning, String>((ref, driverId) async {
  final repo = ref.watch(driverRepositoryProvider);
  return repo.getEarnings(driverId);
});

final driverVehicleProvider = FutureProvider.family<Vehicle, String>((ref, driverId) async {
  final repo = ref.watch(driverRepositoryProvider);
  return repo.getVehicle(driverId);
});

final driverDocumentsProvider = FutureProvider.family<List<DriverDocument>, String>((ref, driverId) async {
  final repo = ref.watch(driverRepositoryProvider);
  return repo.getDocuments(driverId);
});
