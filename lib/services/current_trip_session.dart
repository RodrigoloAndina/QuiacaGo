import 'dart:async';

import 'offline_sync_service.dart';
import 'trip_service.dart';

class CurrentTripSession {
  static final CurrentTripSession _instance = CurrentTripSession._internal();
  factory CurrentTripSession() => _instance;
  CurrentTripSession._internal();

  TripModel? currentTrip;

  void setTrip(TripModel trip) {
    currentTrip = trip;
    unawaited(OfflineSyncService().cacheTrip(trip.toMap()));
  }

  void clear() {
    currentTrip = null;
    unawaited(OfflineSyncService().clearCachedTrip());
  }

  bool get hasTrip => currentTrip != null;

  Future<TripModel?> restore() async {
    try {
    currentTrip = await TripService.obtenerViajeActivo(throwOnError: true);
    if (currentTrip != null) {
      await OfflineSyncService().cacheTrip(currentTrip!.toMap());
      return currentTrip;
    }
    await OfflineSyncService().clearCachedTrip();
    } catch (_) {
      final cached = await OfflineSyncService().readCachedTrip();
      if (cached != null) currentTrip = TripModel.fromMap(cached);
    }
    return currentTrip;
  }
}
