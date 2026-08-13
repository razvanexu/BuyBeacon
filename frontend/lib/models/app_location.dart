/// The app's own location model — decoupled from whichever background
/// geolocation plugin is in use. Only [LocationService] should know about
/// the underlying plugin's location type; everything else in the app
/// depends on this instead.
class AppLocation {
  final double latitude;
  final double longitude;
  final double accuracy;
  final bool isMoving;

  const AppLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.isMoving,
  });
}
