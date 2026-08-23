import 'dart:async';
import 'dart:developer';
import 'dart:math' show max;

import 'package:buy_beacon/models/app_geofence_event.dart';
import 'package:buy_beacon/models/shop_location.dart';
import 'package:buy_beacon/services/location_service.dart';
import 'package:buy_beacon/utils/debug_file_logger.dart';
import 'package:buy_beacon/utils/location_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:tracelet/tracelet.dart' as tl;

/// Wraps the Tracelet plugin's geofencing API. This is the only file
/// (alongside [LocationService]) allowed to import `package:tracelet` --
/// everything else depends on [AppGeofenceEvent] instead, so swapping the
/// underlying tracking plugin again only touches this file.
///
/// Transitions are computed in software from the continuous location stream
/// (see [_checkProximity]), not taken solely from Tracelet's native
/// `onGeofence` callback (still wired up below, kept as a cheap belt-and-
/// suspenders path). On-device testing (POCO X7 / MediaTek, HyperOS/Android
/// 16) showed zero native transitions firing across a 1.5km+ walk past 20+
/// registered geofences, despite continuous GPS updates arriving reliably
/// (1-7s interval) the whole time -- logcat showed the native geofencing HAL
/// repeatedly failing (`geofence_dev_write: invalid fd:-1`). Since we already
/// get a reliable location stream, computing proximity ourselves sidesteps
/// that native path entirely. This also fixes the "already inside when
/// registered" edge case for free, since the software check runs immediately
/// after geofences are added instead of waiting on a native initial-trigger
/// evaluation.
class GeofenceService extends ChangeNotifier {
  static const double _geofenceRadiusMeters = 500;
  static const double _minExitBufferMeters = 30;
  // A single stray fix (good reported accuracy, bad real position -- common
  // indoors with multipath) shouldn't be enough to flip a transition. Require
  // this many *consecutive* location updates to agree before firing.
  static const int _confirmationCount = 2;

  final LocationService _locationService;
  final Map<String, ShopLocation> _geofenceData = {};

  final Set<String> _activeGeofenceIdentifiers = {};
  final Map<String, int> _pendingEnterCounts = {};
  final Map<String, int> _pendingExitCounts = {};

  final _geofenceEventController = StreamController<AppGeofenceEvent>.broadcast();

  Stream<AppGeofenceEvent> get onGeofenceEvent => _geofenceEventController.stream;

  Map<String, ShopLocation> get geofenceData => Map.unmodifiable(_geofenceData);

  Set<String> get activeGeofenceIdentifiers =>
      Set.unmodifiable(_activeGeofenceIdentifiers);

  GeofenceService({required LocationService locationService})
    : _locationService = locationService {
    log('[GeofenceService] Instance created.', name: 'GeofenceService');
  }

  GeofenceAction _toGeofenceAction(tl.GeofenceAction action) {
    switch (action) {
      case tl.GeofenceAction.enter:
        return GeofenceAction.enter;
      case tl.GeofenceAction.exit:
        return GeofenceAction.exit;
      case tl.GeofenceAction.dwell:
        return GeofenceAction.dwell;
    }
  }

  Future<void> initialize() async {
    log(
      '[GeofenceService] Initializing GeofenceService and setting onGeofence listener.',
      name: 'GeofenceService',
    );
    tl.Tracelet.onGeofence(_onGeofence);
    _locationService.addListener(_checkProximity);

    // Native geofences persist across app restarts (that's the point, for background
    // tracking), but _geofenceData is in-memory and resets every launch. Without this,
    // addGeofences()'s diff logic thinks there's nothing stale to remove on a fresh
    // session, so geofences from a previous run pile up indefinitely instead of being
    // replaced by the backend's current results.
    await _clearGeofences();
  }

  @override
  void dispose() {
    _locationService.removeListener(_checkProximity);
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
        await tl.Tracelet.removeGeofence(identifier);
        _geofenceData.remove(identifier);
        _activeGeofenceIdentifiers.remove(identifier);
        _pendingEnterCounts.remove(identifier);
        _pendingExitCounts.remove(identifier);
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
          await tl.Tracelet.addGeofence(
            tl.Geofence(
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
    // Covers shops that are already within radius at the moment they're
    // registered -- native initial-trigger evaluation is unreliable (see the
    // class doc comment), so check immediately instead of waiting for the
    // next location update.
    _checkProximity();
  }

  /// Computes ENTER/EXIT transitions in software from the current location,
  /// since native geofence transitions can't be relied on (see class doc
  /// comment). Runs on every location update.
  ///
  /// EXIT uses a hysteresis buffer on top of the entry radius, scaled to the
  /// current fix's reported accuracy (floored at [_minExitBufferMeters]).
  /// On top of that, both ENTER and EXIT require [_confirmationCount]
  /// consecutive location updates to agree before firing -- indoor testing
  /// showed isolated fixes with *good* reported accuracy but a wildly wrong
  /// real position (multipath), which the accuracy-scaled buffer alone can't
  /// catch since it trusts the (wrong) reported accuracy. A single stray fix
  /// no longer flips a transition; a sustained one still does, just a couple
  /// of location updates later.
  void _checkProximity() {
    final userLocation = _locationService.userLocation;
    if (userLocation == null) return;
    final userPosition = LatLng(userLocation.latitude, userLocation.longitude);
    final exitRadius =
        _geofenceRadiusMeters + max(userLocation.accuracy, _minExitBufferMeters);

    for (final entry in _geofenceData.entries) {
      final identifier = entry.key;
      final shop = entry.value;
      final distance = calculateDistance(
        userPosition,
        LatLng(shop.latitude, shop.longitude),
      );
      final wasInside = _activeGeofenceIdentifiers.contains(identifier);

      if (!wasInside) {
        _pendingExitCounts.remove(identifier);
        if (distance <= _geofenceRadiusMeters) {
          final count = (_pendingEnterCounts[identifier] ?? 0) + 1;
          if (count >= _confirmationCount) {
            _pendingEnterCounts.remove(identifier);
            _emitSoftwareGeofenceEvent(identifier, GeofenceAction.enter);
          } else {
            _pendingEnterCounts[identifier] = count;
          }
        } else {
          _pendingEnterCounts.remove(identifier);
        }
      } else {
        _pendingEnterCounts.remove(identifier);
        if (distance > exitRadius) {
          final count = (_pendingExitCounts[identifier] ?? 0) + 1;
          if (count >= _confirmationCount) {
            _pendingExitCounts.remove(identifier);
            _emitSoftwareGeofenceEvent(identifier, GeofenceAction.exit);
          } else {
            _pendingExitCounts[identifier] = count;
          }
        } else {
          _pendingExitCounts.remove(identifier);
        }
      }
    }
  }

  void _emitSoftwareGeofenceEvent(String identifier, GeofenceAction action) {
    if (kDebugMode) {
      log(
        '[GeofenceService] <<<<< SOFTWARE geofence transition >>>>> ID: $identifier, Action: $action',
        name: 'GeofenceService',
      );
    }
    DebugFileLogger().log(
      'GeofenceService._checkProximity (software) id=$identifier action=$action',
    );
    _geofenceEventController.add(AppGeofenceEvent(identifier: identifier, action: action));
    if (action == GeofenceAction.enter) {
      _activeGeofenceIdentifiers.add(identifier);
    } else if (action == GeofenceAction.exit) {
      _activeGeofenceIdentifiers.remove(identifier);
    }
    notifyListeners();
  }

  Future<void> _clearGeofences() async {
    log('[GeofenceService] _clearGeofences called.', name: 'GeofenceService');
    try {
      await tl.Tracelet.removeGeofences();
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
    _pendingEnterCounts.clear();
    _pendingExitCounts.clear();
    notifyListeners();
  }

  void _onGeofence(tl.GeofenceEvent event) {
    final action = _toGeofenceAction(event.action);
    if (kDebugMode) {
      log(
        '[GeofenceService] <<<<< _onGeofence EVENT RECEIVED >>>>> ID: ${event.identifier}, Action: $action',
        name: 'GeofenceService',
      );
    }
    DebugFileLogger().log('GeofenceService._onGeofence id=${event.identifier} action=$action');
    final appEvent = AppGeofenceEvent(identifier: event.identifier, action: action);
    _geofenceEventController.add(appEvent);
    if (action == GeofenceAction.enter) {
      _activeGeofenceIdentifiers.add(event.identifier);
    } else if (action == GeofenceAction.exit) {
      _activeGeofenceIdentifiers.remove(event.identifier);
    }
    notifyListeners();
  }
}
