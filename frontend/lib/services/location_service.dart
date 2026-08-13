import 'dart:async';
import 'dart:developer';

import 'package:buy_beacon/utils/debug_file_logger.dart';
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
    bg.BackgroundGeolocation.onMotionChange(_onMotionChange);
    bg.BackgroundGeolocation.onActivityChange(_onActivityChange);
    bg.BackgroundGeolocation.onProviderChange(_onProviderChange);

    //listen to geofence events
    bg.BackgroundGeolocation.ready(
      bg.Config(
        desiredAccuracy: bg.Config.DESIRED_ACCURACY_HIGH,
        distanceFilter: 0.0,
        //distance in meters (horizontally) from the location
        locationUpdateInterval: 3000,
        fastestLocationUpdateInterval: 1000,
        //without these, Android's default provider batches updates far
        //slower than distanceFilter:0 implies, so map pin colors lag reality
        stopOnTerminate: false,
        //Continue tracking after the app is terminated
        startOnBoot: true,
        //Restart background tracking after devise reboot
        // TEMPORARY: forced VERBOSE even in release to diagnose why the
        // plugin's motion-detection never fires onActivityChange/onMotionChange
        // on this device -- revert to `kDebugMode ? VERBOSE : ERROR` once resolved.
        logLevel: bg.Config.LOG_LEVEL_VERBOSE,
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

      // On some devices the plugin's automatic stationary/moving detection
      // (accelerometer + Activity Recognition) never fires a single
      // onActivityChange/onMotionChange event, even with all permissions
      // granted and no battery restrictions -- confirmed via on-device
      // debug logging (see DebugFileLogger), leaving it permanently stuck
      // in the "stationary" state and only ever answering one-shot location
      // requests. Forcing "moving" here bypasses that broken auto-detection
      // entirely so continuous GPS sampling actually runs.
      bg.BackgroundGeolocation.changePace(true);
      DebugFileLogger().log('LocationService.initialize forced changePace(true)');

      _startNativeLogDumping();
    });
  }

  DateTime? _lastNativeLogDump;

  // Our own DebugFileLogger only sees events the plugin already decided to
  // fire; it can't say WHY the plugin's motion engine stays silent. The
  // plugin's own native log (bg.Logger) records that reasoning (activity
  // recognition results, stationary/moving transitions, provider requests)
  // but defaults to ERROR-only in release. Poll it periodically and mirror
  // new entries into DebugFileLogger so it's retrievable via the same `adb
  // pull` used for everything else, without needing a live adb session.
  void _startNativeLogDumping() {
    _lastNativeLogDump = DateTime.now();
    Timer.periodic(const Duration(seconds: 45), (_) async {
      final since = _lastNativeLogDump!;
      _lastNativeLogDump = DateTime.now();
      try {
        final nativeLog = await bg.Logger.getLog(bg.SQLQuery(start: since));
        if (nativeLog.trim().isNotEmpty) {
          await DebugFileLogger().log('===== NATIVE SDK LOG (since $since) =====\n$nativeLog');
        }
      } catch (e) {
        await DebugFileLogger().log('Native log dump failed: $e');
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
    DebugFileLogger().log(
      'LocationService._onLocation lat=${location.coords.latitude} '
      'lng=${location.coords.longitude} accuracy=${location.coords.accuracy}',
    );
    _userLocation = location;
    notifyListeners();
  }

  void _onMotionChange(bg.Location location) {
    DebugFileLogger().log(
      'LocationService._onMotionChange isMoving=${location.isMoving} '
      'lat=${location.coords.latitude} lng=${location.coords.longitude}',
    );
  }

  void _onActivityChange(bg.ActivityChangeEvent event) {
    DebugFileLogger().log(
      'LocationService._onActivityChange activity=${event.activity} '
      'confidence=${event.confidence}',
    );
  }

  void _onProviderChange(bg.ProviderChangeEvent event) {
    DebugFileLogger().log(
      'LocationService._onProviderChange enabled=${event.enabled} '
      'status=${event.status} gps=${event.gps} network=${event.network}',
    );
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
