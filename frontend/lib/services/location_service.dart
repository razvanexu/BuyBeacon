import 'dart:developer';

import 'package:flutter/cupertino.dart';
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
        logLevel: bg.Config.LOG_LEVEL_VERBOSE,
        geofenceProximityRadius: 1000,
        //default radius in meters for geofencing
        geofenceInitialTriggerEntry: true,
        // locationUpdateInterval: 5000,
        showsBackgroundLocationIndicator: true,
        debug: true,
        //enable debug sounds / notifications
        notification: bg.Notification(
          smallIcon: '@mipmap/ic_launcher',
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
    log(
      'Location updated: ${location.coords.latitude}, ${location.coords.longitude}',
      name: 'LocationService',
    );
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
      log(
        'Current location: ${location.coords.latitude}, ${location.coords.longitude}',
        name: 'LocationService',
      );
      _onLocation(location);
      return location;
    } catch (e) {
      log('Error getting current location: $e', name: 'LocationService', error: e);
      return null;
    }
  }
}
