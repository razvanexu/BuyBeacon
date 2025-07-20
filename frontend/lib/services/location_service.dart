import 'dart:developer';

import 'package:flutter_background_geolocation/flutter_background_geolocation.dart' as bg;
import 'package:frontend/models/shop_location.dart';
import 'package:frontend/services/notification_service.dart';

class LocationService{
  //Singleton Instance
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;

  final NotificationService notificationService;
  final Map<String, ShopLocation> _geofenceData = {};

  LocationService._internal() : notificationService = NotificationService();

  LocationService.testable({required this.notificationService});

  //geolocation plugin init
  Future<void> initialize() async{
    await notificationService.initialize();

    bg.BackgroundGeolocation.onGeofence(onGeofence);

    //listen to geofence events
    bg.BackgroundGeolocation.ready(bg.Config(
      desiredAccuracy: bg.Config.DESIRED_ACCURACY_HIGH,
      distanceFilter: 10.0, //distance in meters (horizontally) from the location
      stopOnTerminate: false, //Continue tracking after the app is terminated
      startOnBoot: true, //Restart background tracking after devise reboot
      logLevel: bg.Config.LOG_LEVEL_VERBOSE,
      geofenceProximityRadius: 1000, //default radius in meters for geofencing
      debug: true, //enable debug sounds / notifications
      notification: bg.Notification(
        smallIcon: '@mipmap/ic_launcher',
        channelId: 'buybeacon_location_channel',
        channelName: 'BuyBeacon Location Service',
        title: 'BuyBeacon is running',
        text: 'Tracking your location in the background',
      )
    )).then((bg.State state){
      if(!state.enabled){
        //start tracking service
        bg.BackgroundGeolocation.startGeofences();
        log('Background geolocation started.', name: 'LocationService');
      }
    });
  }

  //Geofence event handler
  void onGeofence(bg.GeofenceEvent event){
    log('Geofence event triggered: $event', name: 'LocationService');
    //trigger notification event for user
    // (ex. "you are near {store name} that might have product x")
    if(event.action == 'ENTER'){
      log('User entered geofence: ${event.identifier}', name: 'LocationService');

      final locationData = _geofenceData[event.identifier];
      String body;
      if(locationData != null && locationData.products.isNotEmpty){
        final storeName = locationData.name;
        final products = locationData.products.join(', ');
        body = 'You are near $storeName, which might have: $products';
      }else{
        body = 'You are near a store that might have an item on your list!';
      }
      
      notificationService.showNotification(
          title: 'BuyBeacon reminder',
          body: body,
          payload: event.identifier
      );
    }
  }

  //Public methods
  Future<void> addGeofences(List<ShopLocation> locations) async{
    log('Adding ${locations.length} geofences.', name: 'LocationService');
    await bg.BackgroundGeolocation.removeGeofences(); //clear old fences first
    _geofenceData.clear();
    for(var location in locations){
      try{
        final identifier = 'shop_${location.latitude}_${location.longitude}';
        //store location data in cache
        _geofenceData[identifier] = location;

        await bg.BackgroundGeolocation.addGeofence(bg.Geofence(
          identifier: 'shop_${location.latitude}_${location.longitude}', //unique id
          radius: 500, //radius in meters
          latitude: location.latitude,
          longitude: location.longitude,
          notifyOnEntry: true,
          notifyOnExit: false,
          notifyOnDwell: false
        ));
        log('Successfully added geofence for ${location.latitude}, ${location.longitude}', name: 'LocationService');
      }catch(e){
        log('Error adding geofence: $e', name: 'LocationService', error: e);
      }
    }
  }

  Future<void> clearGeoFences() async{
    log('Clearing all geofences', name: 'LocationService');
    await bg.BackgroundGeolocation.removeGeofences();
    _geofenceData.clear();
  }
}