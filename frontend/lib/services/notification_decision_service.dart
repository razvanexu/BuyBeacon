import 'dart:async';
import 'dart:developer';

import 'package:buy_beacon/models/app_geofence_event.dart';
import 'package:buy_beacon/models/shop_location.dart';
import 'package:buy_beacon/services/geofence_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../utils/location_utils.dart';
import 'location_service.dart';
import 'notification_service.dart';

class NotificationDecisionService {
  final GeofenceService _geofenceService;
  final NotificationService _notificationService;
  final LocationService _locationService;

  StreamSubscription? _geofenceSubscription;
  Timer? _notificationDebouncetimer;
  final Set<String> _pendingNotificationGeofences = {};
  final duration = Duration(seconds: 5);

  NotificationDecisionService({
    required GeofenceService geofenceService,
    required NotificationService notificationService,
    required LocationService locationService,
  }) : _geofenceService = geofenceService,
       _notificationService = notificationService,
       _locationService = locationService;

  void initialize() {
    log(
      '[NotificationDecisionService] Initializing...',
      name: 'NotificationDecisionService',
    );
    _geofenceSubscription = _geofenceService.onGeofenceEvent.listen(_onGeofenceEvent);
  }

  void dispose() {
    log(
      '[NotificationDecisionService] Disposing...',
      name: 'NotificationDecisionService',
    );
    _geofenceSubscription?.cancel();
    _notificationDebouncetimer?.cancel();
  }

  void _onGeofenceEvent(AppGeofenceEvent event) {
    if (event.action == GeofenceAction.enter) {
      _pendingNotificationGeofences.add(event.identifier);
      _notificationDebouncetimer?.cancel();
      _notificationDebouncetimer = Timer(duration, _processPendingNotifications);
      log(
        '[NotificationDecisionService] Added ${event.identifier} to pending and started 15s timer.',
        name: 'NotificationDecisionService',
      );
    } else if (event.action == GeofenceAction.exit) {
      _pendingNotificationGeofences.remove(event.identifier);
    }
  }

  Future<void> _processPendingNotifications() async {
    log(
      '[NotificationDecisionService] Debounce timer fired. Processing ${_pendingNotificationGeofences.length} pending geofences.',
      name: 'NotificationDecisionService',
    );
    if (_pendingNotificationGeofences.isEmpty) return;

    final currentLocation = await _locationService.getCurrentLocation();
    if (currentLocation == null) {
      log(
        '[NotificationDecisionService] Could not get current location. Aborting notification.',
        name: 'NotificationDecisionService',
      );
      _pendingNotificationGeofences.clear();
      return;
    }

    ShopLocation? closestShop;
    double minDistance = double.infinity;
    final userPosition = LatLng(currentLocation.latitude, currentLocation.longitude);

    for (final identifier in _pendingNotificationGeofences) {
      final shop = _geofenceService.geofenceData[identifier];
      if (shop != null) {
        final distance = calculateDistance(
          userPosition,
          LatLng(shop.latitude, shop.longitude),
        );
        if (distance < minDistance) {
          minDistance = distance;
          closestShop = shop;
        }
      }
    }

    if (closestShop != null && closestShop.products.isNotEmpty) {
      log(
        '[NotificationDecisionService] Determined nearest shop: ${closestShop.name}. Sending notification.',
        name: 'NotificationDecisionService',
      );
      final storeName = closestShop.name;
      final products = closestShop.products.join(', ');
      final body = 'You are near $storeName which might have $products';
      _notificationService.showNotification(
        title: 'Buy Beacon reminder',
        body: body,
        payload: storeName,
      );
    } else {
      log(
        '[NotificationDecisionService] No valid closest shop found. No notification sent.',
        name: 'NotificationDecisionService',
      );
    }
    _pendingNotificationGeofences.clear();
  }
}
