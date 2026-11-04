/// The app's own location model — decoupled from whichever background
/// geolocation plugin is in use. Only [LocationService] should know about
/// the underlying plugin's location type; everything else in the app
/// depends on this instead.
class AppLocation {
  final double latitude;
  final double longitude;
  final double accuracy;
  final bool isMoving;

  /// When this fix was received. Null only in tests that construct
  /// [AppLocation] directly without going through [LocationService] --
  /// production code always sets it, so staleness checks (see
  /// ShoppingOrchestrator) can tell a fresh fix from one Tracelet cached
  /// minutes ago while throttled in its stationary/low-power mode.
  final DateTime? timestamp;

  const AppLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.isMoving,
    this.timestamp,
  });
}
