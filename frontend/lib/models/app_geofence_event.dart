/// The app's own geofence transition event — decoupled from whichever
/// background geolocation plugin is in use. Only [GeofenceService] should
/// know about the underlying plugin's event type; everything else in the
/// app depends on this instead.
enum GeofenceAction { enter, exit, dwell }

class AppGeofenceEvent {
  final String identifier;
  final GeofenceAction action;

  const AppGeofenceEvent({required this.identifier, required this.action});
}
