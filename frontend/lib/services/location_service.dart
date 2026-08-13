import 'dart:developer';

import 'package:buy_beacon/models/app_location.dart';
import 'package:buy_beacon/utils/debug_file_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:tracelet/tracelet.dart' as tl;

/// Wraps the Tracelet plugin. This is the only file in the app allowed to
/// import `package:tracelet` -- everything else depends on [AppLocation]
/// instead, so swapping the underlying tracking plugin again only touches
/// this file (and [GeofenceService]).
class LocationService extends ChangeNotifier {
  //Singleton Instance
  static final LocationService _instance = LocationService._internal();

  factory LocationService() => _instance;

  LocationService._internal();

  AppLocation? _userLocation;

  AppLocation? get userLocation => _userLocation;

  AppLocation _toAppLocation(tl.Location location) => AppLocation(
    latitude: location.coords.latitude,
    longitude: location.coords.longitude,
    accuracy: location.coords.accuracy,
    isMoving: location.isMoving,
  );

  //geolocation plugin init
  Future<void> initialize({required AndroidNotificationChannel channel}) async {
    log('[LocationService] Initializing...', name: 'LocationService');
    tl.Tracelet.onLocation(_onLocation);

    // Must request (and get at least "when in use") location permission
    // *before* calling ready()/start(): on Android 14+, starting Tracelet's
    // location-type foreground service without the permission already
    // granted makes the OS reject the notification and force-kill the whole
    // app (CannotPostForegroundServiceNotificationException), not just log
    // an error. requestLocationAuthorization() escalates automatically
    // (notDetermined -> when-in-use -> always) across repeated calls.
    final authStatus = await tl.Tracelet.requestLocationAuthorization();
    log('[LocationService] Location authorization status: $authStatus', name: 'LocationService');
    await tl.Tracelet.requestNotificationAuthorization();

    if (authStatus == tl.AuthorizationStatus.denied) {
      log(
        '[LocationService] Location permission denied; skipping Tracelet startup to avoid the '
        'foreground-service crash. Tracking will stay off until permission is granted.',
        name: 'LocationService',
      );
      DebugFileLogger().log(
        'LocationService.initialize aborted: location permission denied ($authStatus)',
      );
      return;
    }

    try {
      final state = await tl.Tracelet.ready(
        tl.Config.balanced().copyWith(
          geo: const tl.GeoConfig(desiredAccuracy: tl.DesiredAccuracy.high, distanceFilter: 0.0),
          app: const tl.AppConfig(stopOnTerminate: false, startOnBoot: true),
          android: tl.AndroidConfig(
            // Android's default provider batches updates far slower than
            // distanceFilter:0 implies without these explicit intervals, so
            // map pin colors would lag reality.
            locationUpdateInterval: 3000,
            fastestLocationUpdateInterval: 1000,
            foregroundService: const tl.ForegroundServiceConfig(
              notificationTitle: 'BuyBeacon is running',
              notificationText: 'Monitoring for nearby stores.',
              // Without an explicit flat/alpha-masked icon, Android rejects the
              // foreground-service notification outright (mipmap/ic_launcher is
              // full-color, invalid for a status-bar icon) and force-kills the
              // app with CannotPostForegroundServiceNotificationException --
              // same underlying issue hit with the previous plugin.
              notificationSmallIcon: 'ic_stat_notify',
            ),
          ),
          logger: tl.LoggerConfig(debug: kDebugMode, logLevel: tl.LogLevel.error),
        ),
      );
      log(
        '[LocationService] Tracelet.ready complete. State enabled: ${state.enabled}',
        name: 'LocationService',
      );
      if (!state.enabled) {
        await tl.Tracelet.start();
        log('[LocationService] Tracelet.start() called and completed.', name: 'LocationService');
      }
    } catch (e) {
      log('[LocationService] Tracelet ready/start failed: $e', name: 'LocationService', error: e);
      DebugFileLogger().log('LocationService.initialize ready/start failed: $e');
      return;
    }

    // A safety net: on some devices/OEMs the plugin's automatic
    // stationary/moving detection can fail to trigger continuous tracking.
    // Forcing "moving" here bypasses that so continuous GPS sampling runs
    // regardless. Awaited and logged (not fire-and-forget) so a failure is
    // visible instead of silently swallowed.
    try {
      await tl.Tracelet.changePace(true);
    } catch (e) {
      log('[LocationService] changePace(true) failed: $e', name: 'LocationService', error: e);
      DebugFileLogger().log('LocationService.initialize changePace(true) failed: $e');
    }
  }

  void _onLocation(tl.Location location) {
    if (kDebugMode) {
      log(
        'Location updated: ${location.coords.latitude}, ${location.coords.longitude}',
        name: 'LocationService',
      );
    }
    _userLocation = _toAppLocation(location);
    DebugFileLogger().log(
      'LocationService._onLocation lat=${_userLocation!.latitude} '
      'lng=${_userLocation!.longitude} accuracy=${_userLocation!.accuracy}',
    );
    notifyListeners();
  }

  Future<AppLocation?> getCurrentLocation() async {
    log('[LocationService] getCurrentLocation() called.', name: 'LocationService');
    try {
      final location = await tl.Tracelet.getCurrentPosition(persist: true, samples: 1, timeout: 5);
      _onLocation(location);
      return _userLocation;
    } catch (e) {
      log('Error getting current location: $e', name: 'LocationService', error: e);
      return null;
    }
  }
}
