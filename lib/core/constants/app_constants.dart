enum DriverStatus {
  OFFLINE,
  AVAILABLE,
  ON_TRIP
}

enum TripStatus {
  REQUESTED,
  ACCEPTED,
  ARRIVING,
  WAITING_PASSENGER,
  STARTED,
  FINISHED,
  CANCELLED
}

enum DocumentStatus {
  APPROVED,
  PENDING,
  EXPIRED
}

class AppConstants {
  static const String appName = 'QuiacaGo Conductor';
  static const int acceptTripTimeoutSeconds = 15;

  // Ubicación por defecto: La Quiaca, Jujuy, Argentina
  static const double laQuiacaLat = -22.1023;
  static const double laQuiacaLng = -65.5982;
}
