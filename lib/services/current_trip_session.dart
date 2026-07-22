import 'trip_service.dart';

class CurrentTripSession {
  static final CurrentTripSession _instance = CurrentTripSession._internal();
  factory CurrentTripSession() => _instance;
  CurrentTripSession._internal();

  TripModel? currentTrip;

  void setTrip(TripModel trip) {
    currentTrip = trip;
  }

  void clear() {
    currentTrip = null;
  }

  bool get hasTrip => currentTrip != null;
}
