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
    currentTrip = await TripService.obtenerViajeActivo();
    if (currentTrip != null) {
      await OfflineSyncService().cacheTrip(currentTrip!.toMap());
      return currentTrip;
    }
    if (!OfflineSyncService().isOnline) {
      final cached = await OfflineSyncService().readCachedTrip();
      if (cached != null) currentTrip = TripModel.fromMap(cached);
    } else {
      await OfflineSyncService().clearCachedTrip();
    }
    return currentTrip;
  }
}
