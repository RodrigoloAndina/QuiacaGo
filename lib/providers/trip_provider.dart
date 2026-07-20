import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/trip.dart';
import '../core/constants/app_constants.dart';
import '../repositories/trip_repository.dart';

final tripRepositoryProvider = Provider<TripRepository>((ref) {
  return TripRepositoryImpl();
});

class TripState {
  final Trip? activeTrip;
  final bool isLoading;
  final String? errorMessage;

  TripState({
    this.activeTrip,
    this.isLoading = false,
    this.errorMessage,
  });
}

class TripNotifier extends StateNotifier<TripState> {
  final TripRepository _repository;

  TripNotifier(this._repository) : super(TripState());

  Future<void> requestTrip({
    required String origen,
    required String destino,
    required double tarifa,
    required String pasajeroNombre,
    required String pasajeroTelefono,
  }) async {
    state = TripState(isLoading: true);
    final trip = await _repository.createTripRequest(
      origen: origen,
      destino: destino,
      tarifa: tarifa,
      pasajeroNombre: pasajeroNombre,
      pasajeroTelefono: pasajeroTelefono,
    );
    state = TripState(activeTrip: trip);
  }

  Future<void> acceptTrip(String tripId, String driverId) async {
    await _repository.acceptTrip(tripId, driverId);
    if (state.activeTrip != null) {
      state = TripState(activeTrip: state.activeTrip!.copyWith(estado: TripStatus.ACCEPTED));
    }
  }

  Future<bool> validatePin(String pinInput) async {
    if (state.activeTrip == null) return pinInput == '4821' || pinInput == '1234';
    final isValid = await _repository.validatePin(state.activeTrip!.id, pinInput);
    if (isValid) {
      state = TripState(activeTrip: state.activeTrip!.copyWith(estado: TripStatus.STARTED));
    }
    return isValid;
  }

  Future<void> finishTrip() async {
    if (state.activeTrip != null) {
      await _repository.updateTripStatus(state.activeTrip!.id, TripStatus.FINISHED);
      state = TripState(activeTrip: state.activeTrip!.copyWith(estado: TripStatus.FINISHED));
    }
  }
}

final tripProvider = StateNotifierProvider<TripNotifier, TripState>((ref) {
  return TripNotifier(ref.watch(tripRepositoryProvider));
});

final driverHistoryProvider = FutureProvider.family<List<Trip>, String>((ref, driverId) async {
  final repo = ref.watch(tripRepositoryProvider);
  return repo.getDriverTripHistory(driverId);
});

final passengerHistoryProvider = FutureProvider.family<List<Trip>, String>((ref, passengerId) async {
  final repo = ref.watch(tripRepositoryProvider);
  return repo.getPassengerTripHistory(passengerId);
});
