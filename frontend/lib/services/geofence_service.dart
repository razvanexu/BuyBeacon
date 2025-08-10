import 'dart:async';
import 'dart:developer';

import 'package:buy_beacon/models/shop_location.dart';
import 'package:buy_beacon/services/location_service.dart';
import 'package:buy_beacon/services/notification_service.dart';
import 'package:buy_beacon/utils/location_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart' as bg;
import 'package:google_maps_flutter/google_maps_flutter.dart';

class GeofenceService extends ChangeNotifier {
  final NotificationService _notificationService;
  final LocationService _locationService;
  final Map<String, ShopLocation> _geofenceData = {};
  Timer? _debounce;

  final Set<String> _activeGeofenceIdentifiers = {};

  Set<String> get activeGeofenceIdentifiers =>
      Set.unmodifiable(_activeGeofenceIdentifiers);

  GeofenceService({
    required NotificationService notificationService,
    required LocationService locationService,
  }) : _notificationService = notificationService,
       _locationService = locationService {
    log('[GeofenceService] Instance created.', name: 'GeofenceService');
  }

  void initialize() {
    log(
      '[GeofenceService] Initializing GeofenceService and setting onGeofence listener.',
      name: 'GeofenceService',
    );
    bg.BackgroundGeolocation.onGeofence(_onGeofence);
  }

  Future<void> addGeofences(List<ShopLocation> newLocations) async {
    log(
      '[GeofenceService] addGeofences called with ${newLocations.length} locations.',
      name: 'GeofenceService',
    );
    if (newLocations.isEmpty) {
      await _clearGeofences();
      log(
        '[GeofenceService] No locations to add as geofences. Clearing all geofences.',
        name: 'GeofenceService',
      );
      return;
    }

    final newIdentifiers = newLocations
        .map((loc) => 'shop_${loc.latitude}_${loc.longitude}')
        .toSet();

    final currentIdentifiers = _geofenceData.keys.toSet();

    final geofencesToRemove = currentIdentifiers.difference(newIdentifiers);

    for (final identifier in geofencesToRemove) {
      try {
        await bg.BackgroundGeolocation.removeGeofence(identifier);
        _geofenceData.remove(identifier);
        _activeGeofenceIdentifiers.remove(identifier);
        log(
          '[GeofenceService] Successfully REMOVED stale geofence: $identifier',
          name: 'GeofenceService',
        );
      } catch (e) {
        log(
          '[GeofenceService] Error removing stale geofence $identifier: $e',
          name: 'GeofenceService',
          error: e,
        );
      }
    }

    for (final location in newLocations) {
      final identifier = 'shop_${location.latitude}_${location.longitude}';
      log(
        '[GeofenceService] Preparing to ADD or UPDATE geofence:'
        'ID=$identifier,'
        'Lat=${location.latitude}, Lon=${location.longitude},'
        'Name=${location.name}',
        name: 'GeofenceService',
      );

      if (currentIdentifiers.contains(identifier)) {
        _geofenceData[identifier] = location;
        log(
          '[GeofenceService] Successfully UPDATED geofence data: $identifier',
          name: 'GeofenceService',
        );
      } else {
        _geofenceData[identifier] = location;
        try {
          await bg.BackgroundGeolocation.addGeofence(
            bg.Geofence(
              identifier: identifier,
              latitude: location.latitude,
              longitude: location.longitude,
              radius: 500,
              notifyOnEntry: true,
              notifyOnExit: true,
              notifyOnDwell: false,
              extras: {'shopName': location.name},
            ),
          );
          log(
            '[GeofenceService] Successfully ADDED new geofence to plugin: $identifier',
            name: 'GeofenceService',
          );
        } catch (e) {
          log(
            '[GeofenceService] Error adding geofence $identifier to plugin: $e',
            name: 'GeofenceService',
            error: e,
          );
          _geofenceData.remove(identifier);
        }
      }
    }
    log(
      '[GeofenceService] Finished adding geofences. Total in local cache: ${_geofenceData.length}',
      name: 'GeofenceService',
    );
    notifyListeners();
    log(
      '[GeofenceService] Finished geofence diffing. Total in local cache: ${_geofenceData.length}',
      name: 'GeofenceService',
    );
  }

  Future<void> _clearGeofences() async {
    log('[GeofenceService] _clearGeofences called.', name: 'GeofenceService');
    try {
      await bg.BackgroundGeolocation.removeGeofences();
      log(
        '[GeofenceService] Successfully removed all geofences from plugin.',
        name: 'GeofenceService',
      );
    } catch (e) {
      log(
        '[GeofenceService] Error calling removeGeofences() from plugin: $e',
        name: 'GeofenceService',
        error: e,
      );
    }
    _geofenceData.clear();
    _activeGeofenceIdentifiers.clear();
    notifyListeners();
  }

  void _onGeofence(bg.GeofenceEvent event) {
    log(
      '[GeofenceService] <<<<< _onGeofence EVENT RECEIVED >>>>> ID: ${event.identifier}, Action: ${event.action}',
      name: 'GeofenceService',
    );

    if (event.action == 'ENTER') {
      _activeGeofenceIdentifiers.add(event.identifier);
    } else if (event.action == 'EXIT') {
      _activeGeofenceIdentifiers.remove(event.identifier);
    }

    // Debounce the handling to prevent rapid firing from multiple simultaneous events.
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(seconds: 2), () {
      _handleGeofenceChange();
      notifyListeners();
    });
  }

  Future<void> _handleGeofenceChange() async {
    log(
      '[GeofenceService] Handling geofence change. Active geofences: ${_activeGeofenceIdentifiers.length}',
      name: 'GeofenceService',
    );

    if (_activeGeofenceIdentifiers.isEmpty) {
      return;
    }

    final currentLocation = await _locationService.getCurrentLocation();
    if (currentLocation == null) {
      log(
        '[GeofenceService] Could not get current location to determine nearest shop.',
        name: 'GeofenceService',
      );
      return;
    }

    ShopLocation? nearestShop;
    double minDistance = double.infinity;

    for (final activeId in _activeGeofenceIdentifiers) {
      final shopLocation = _geofenceData[activeId];
      if (shopLocation != null) {
        final distance = calculateDistance(
          LatLng(currentLocation.coords.latitude, currentLocation.coords.longitude),
          LatLng(shopLocation.latitude, shopLocation.longitude),
        );

        if (distance < minDistance) {
          minDistance = distance;
          nearestShop = shopLocation;
        }
      }
    }

    if (nearestShop != null) {
      if (nearestShop.products.isNotEmpty) {
        log(
          '[GeofenceService] Determined nearest active shop: ${nearestShop.name}. Preparing notification.',
          name: 'GeofenceService',
        );
        final storeName = nearestShop.name;
        final products = nearestShop.products.join(', ');
        final body = 'You are near $storeName which might have $products';
        _notificationService.showNotification(
          title: 'Buy Beacon reminder',
          body: body,
          payload: nearestShop.name,
        );
      } else {
        log(
          '[GeofenceService] ERROR: Nearest active shop ${nearestShop.name} has no products listed.',
          name: 'GeofenceService',
        );
      }
    }
  }
}
