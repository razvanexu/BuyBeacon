import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart' as bg;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocationService extends ChangeNotifier {
  //Singleton Instance
  static final LocationService _instance = LocationService._internal();

  factory LocationService() => _instance;

  LocationService._internal();

  bg.Location? _userLocation;

  bg.Location? get userLocation => _userLocation;

  //geolocation plugin init
  Future<void> initialize({required AndroidNotificationChannel channel}) async {
    log('[LocationService] Initializing...', name: 'LocationService');
    bg.BackgroundGeolocation.onLocation(_onLocation);

    //listen to geofence events
    bg.BackgroundGeolocation.ready(
      bg.Config(
        desiredAccuracy: bg.Config.DESIRED_ACCURACY_HIGH,
        distanceFilter: 0.0,
        //distance in meters (horizontally) from the location
        stopOnTerminate: false,
        //Continue tracking after the app is terminated
        startOnBoot: true,
        //Restart background tracking after devise reboot
        logLevel: kDebugMode ? bg.Config.LOG_LEVEL_VERBOSE : bg.Config.LOG_LEVEL_ERROR,
        geofenceProximityRadius: 1000,
        //default radius in meters for geofencing
        geofenceInitialTriggerEntry: true,
        stopTimeout: 1,
        showsBackgroundLocationIndicator: true,
        //debug sounds/notifications only in debug builds
        debug: kDebugMode,
        notification: bg.Notification(
          // ic_launcher is a full-color launcher icon, which Android rejects for
          // foreground-service notifications ("Invalid notification (no valid small icon)").
          // Notification small icons must be a flat, alpha-masked silhouette instead.
          smallIcon: 'drawable/ic_stat_notify',
          channelId: channel.id,
          channelName: channel.name,
          title: 'BuyBeacon is running',
          text: 'Monitoring for nearby stores.',
        ),
      ),
    ).then((bg.State state) {
      log(
        '[LocationService] BackgroundGeolocation.ready complete. State enabled: ${state.enabled}',
        name: 'LocationService',
      );
      if (!state.enabled) {
        //start tracking service
        bg.BackgroundGeolocation.start();
        log(
          '[LocationService] BackgroundGeolocation.start() called and completed.',
          name: 'LocationService',
        );
      }
    });
  }

  void _onLocation(bg.Location location) {
    if (kDebugMode) {
      log(
        'Location updated: ${location.coords.latitude}, ${location.coords.longitude}',
        name: 'LocationService',
      );
    }
    _userLocation = location;
    notifyListeners();
  }

  Future<bg.Location?> getCurrentLocation() async {
    log('[LocationService] getCurrentLocation() called.', name: 'LocationService');
    try {
      final location = await bg.BackgroundGeolocation.getCurrentPosition(
        persist: true,
        samples: 1,
        timeout: 5000,
      );
      _onLocation(location);
      return location;
    } catch (e) {
      log('Error getting current location: $e', name: 'LocationService', error: e);
      return null;
    }
  }
}
