import 'dart:async';
import 'dart:developer';

import 'package:buy_beacon/models/shop_location.dart';
import 'package:buy_beacon/services/location_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart' as bg;

class GeofenceService extends ChangeNotifier {
  final LocationService _locationService;
  final Map<String, ShopLocation> _geofenceData = {};

  final Set<String> _activeGeofenceIdentifiers = {};

  final _geofenceEventController = StreamController<bg.GeofenceEvent>.broadcast();

  Stream<bg.GeofenceEvent> get onGeofenceEvent => _geofenceEventController.stream;

  Map<String, ShopLocation> get geofenceData => Map.unmodifiable(_geofenceData);

  Set<String> get activeGeofenceIdentifiers =>
      Set.unmodifiable(_activeGeofenceIdentifiers);

  GeofenceService({required LocationService locationService})
    : _locationService = locationService {
    log('[GeofenceService] Instance created.', name: 'GeofenceService');
  }

  Future<void> initialize() async {
    log(
      '[GeofenceService] Initializing GeofenceService and setting onGeofence listener.',
      name: 'GeofenceService',
    );
    bg.BackgroundGeolocation.onGeofence(_onGeofence);

    // Native geofences persist across app restarts (that's the point, for background
    // tracking), but _geofenceData is in-memory and resets every launch. Without this,
    // addGeofences()'s diff logic thinks there's nothing stale to remove on a fresh
    // session, so geofences from a previous run pile up indefinitely instead of being
    // replaced by the backend's current results.
    await _clearGeofences();
  }

  @override
  void dispose() {
    _geofenceEventController.close();
    super.dispose();
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
      if (kDebugMode) {
        log(
          '[GeofenceService] Preparing to ADD or UPDATE geofence:'
          'ID=$identifier,'
          'Lat=${location.latitude}, Lon=${location.longitude},'
          'Name=${location.name}',
          name: 'GeofenceService',
        );
      }

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
    await _locationService.getCurrentLocation();
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
    if (kDebugMode) {
      log(
        '[GeofenceService] <<<<< _onGeofence EVENT RECEIVED >>>>> ID: ${event.identifier}, Action: ${event.action}',
        name: 'GeofenceService',
      );
    }
    _geofenceEventController.add(event);
    if (event.action == 'ENTER') {
      _activeGeofenceIdentifiers.add(event.identifier);
    } else if (event.action == 'EXIT') {
      _activeGeofenceIdentifiers.remove(event.identifier);
    }
    notifyListeners();
  }
}
