/// Shared resource budget for the closed pilot. Backend presence TTL is 45 s.
class AppRuntimePolicy {
  static const locationHeartbeat = Duration(seconds: 15);
  static const locationFreshness = Duration(seconds: 45);
  static const connectivityProbe = Duration(seconds: 30);
  static const connectivityCache = Duration(seconds: 5);
  static const fareCache = Duration(minutes: 5);
}
