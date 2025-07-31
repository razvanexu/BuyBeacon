import 'dart:developer';

import 'package:buy_beacon/models/shop_location.dart';
import 'package:buy_beacon/services/notification_service.dart';
import 'package:buy_beacon/utils/location_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart' as bg;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationService extends ChangeNotifier {
  //Singleton Instance
  static final LocationService _instance = LocationService._internal();

  factory LocationService() => _instance;

  final NotificationService notificationService;
  final Map<String, ShopLocation> _geofenceData = {};
  final Set<String> _activeGeofenceIdentifiers = {};
  bg.Location? _userLocation;

  List<ShopLocation> get monitoredShopLocations => _geofenceData.values.toList();

  Set<String> get activeGeofenceIdentifiers => _activeGeofenceIdentifiers;

  bg.Location? get userLocation => _userLocation;

  LocationService._internal() : notificationService = NotificationService();

  LocationService.testable({required this.notificationService});

  //geolocation plugin init
  Future<void> initialize({
    void Function(NotificationResponse response)? onNotificationTap,
  }) async {
    bg.BackgroundGeolocation.onGeofence(onGeofence);
    bg.BackgroundGeolocation.onLocation(onLocation);

    //listen to geofence events
    bg.BackgroundGeolocation.ready(
      bg.Config(
        desiredAccuracy: bg.Config.DESIRED_ACCURACY_HIGH,
        distanceFilter: 10.0,
        //distance in meters (horizontally) from the location
        stopOnTerminate: false,
        //Continue tracking after the app is terminated
        startOnBoot: true,
        //Restart background tracking after devise reboot
        logLevel: bg.Config.LOG_LEVEL_VERBOSE,
        geofenceProximityRadius: 1000,
        //default radius in meters for geofencing
        debug: true,
        //enable debug sounds / notifications
        notification: bg.Notification(
          smallIcon: '@mipmap/ic_launcher',
          channelId: 'buybeacon_location_channel',
          channelName: 'BuyBeacon Location Service',
          title: 'BuyBeacon is running',
          text: 'Tracking your location in the background',
        ),
      ),
    ).then((bg.State state) {
      if (!state.enabled) {
        //start tracking service
        bg.BackgroundGeolocation.startGeofences();
        log('Background geolocation started.', name: 'LocationService');
      }
    });
  }

  void onLocation(bg.Location location) {
    log(
      'Location updated: ${location.coords.latitude}, ${location.coords.longitude}',
      name: 'LocationService',
    );
    _userLocation = location;
    notifyListeners();
  }

  //Geofence event handler
  Future<void> onGeofence(bg.GeofenceEvent event) async {
    log('Geofence event triggered: $event', name: 'LocationService');
    //trigger notification event for user
    // (ex. "you are near {store name} that might have product x")
    if (event.action == 'ENTER') {
      log('User entered geofence: ${event.identifier}', name: 'LocationService');
      _activeGeofenceIdentifiers.add(event.identifier);

      //Get current location
      bg.Location? currentLocation = await getCurrentLocation();
      if (currentLocation == null) {
        log(
          'Cannot determine current location for geofence event. Aborting notification.',
          name: 'LocationService',
        );
        return;
      }

      //Get all currently monitored geofences
      ShopLocation? nearestShop;
      double minDistance = double.infinity;

      for (var entry in _geofenceData.entries) {
        final geoIdentifier = entry.key;
        final shopLocation = entry.value;

        final distance = calculateDistance(
          LatLng(currentLocation.coords.latitude, currentLocation.coords.longitude),
          LatLng(shopLocation.latitude, shopLocation.longitude),
        );
        log(
          'Distance to ${shopLocation.name} ($geoIdentifier): ${distance.toStringAsFixed(2)} meters',
          name: 'LocationService',
        );
        if (distance < minDistance) {
          minDistance = distance;
          nearestShop = shopLocation;
        }
      }

      if (nearestShop != null &&
          event.identifier == 'shop_${nearestShop.latitude}_${nearestShop.longitude}') {
        log(
          'Entered geofence (${event.identifier}) is the nearest shop. Showing'
          'notification.',
          name: 'LocationService',
        );
        String body;
        if (nearestShop.products.isNotEmpty) {
          final storeName = nearestShop.name;
          final products = nearestShop.products.join(', ');
          body = 'You are near $storeName which might have $products';
        } else {
          body = 'You are near a store that might have a product on your list';
        }

        notificationService.showNotification(
          title: 'BuyBeacon reminder',
          body: body,
          payload: nearestShop.name,
        );
      } else if (nearestShop == null) {
        log(
          'Entered geofence (${event.identifier}) is NOT the nearest shop'
          '(${nearestShop?.name}). Not showing notification.',
          name: 'LocationService',
        );
      } else {
        log(
          'No nearest shop found among monitored geofences for notification.',
          name: 'LocationService',
        );
      }
    } else if (event.action == 'EXIT') {
      log('User exited geofence: ${event.identifier}', name: 'LocationService');
      _activeGeofenceIdentifiers.remove(
        event.identifier,
      ); // REMOVED: Remove from active list
      notifyListeners(); // ADDED: Notify listeners of change
    }
  }

  //Public methods
  Future<void> addGeofences(List<ShopLocation> locations) async {
    log('Adding ${locations.length} geofences.', name: 'LocationService');
    await bg.BackgroundGeolocation.removeGeofences(); //clear old fences first
    _geofenceData.clear();
    _activeGeofenceIdentifiers.clear();
    for (var location in locations) {
      try {
        final identifier = 'shop_${location.latitude}_${location.longitude}';
        //store location data in cache
        _geofenceData[identifier] = location;

        await bg.BackgroundGeolocation.addGeofence(
          bg.Geofence(
            identifier: 'shop_${location.latitude}_${location.longitude}',
            //unique id
            radius: 500,
            //radius in meters
            latitude: location.latitude,
            longitude: location.longitude,
            notifyOnEntry: true,
            notifyOnExit: true,
            notifyOnDwell: false,
          ),
        );
        log(
          'Successfully added geofence for ${location.latitude}, ${location.longitude}',
          name: 'LocationService',
        );
      } catch (e) {
        log('Error adding geofence: $e', name: 'LocationService', error: e);
      }
    }
    notifyListeners();
  }

  Future<void> clearGeoFences() async {
    log('Clearing all geofences', name: 'LocationService');
    await bg.BackgroundGeolocation.removeGeofences();
    _geofenceData.clear();
    _activeGeofenceIdentifiers.clear();
    notifyListeners();
  }

  Future<bg.Location?> getCurrentLocation() async {
    try {
      final location = await bg.BackgroundGeolocation.getCurrentPosition(
        persist: true,
        samples: 1,
      );
      log(
        'Current location: ${location.coords.latitude}, ${location.coords.longitude}',
        name: 'LocationService',
      );
      _userLocation = location;
      notifyListeners();
      return location;
    } catch (e) {
      log('Error getting current location: $e', name: 'LocationService', error: e);
      return null;
    }
  }
}
