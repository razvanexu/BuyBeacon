import 'dart:async';
import 'dart:developer';
import 'dart:math' show max;

import 'package:buy_beacon/models/app_geofence_event.dart';
import 'package:buy_beacon/models/app_location.dart';
import 'package:buy_beacon/models/shop_location.dart';
import 'package:buy_beacon/services/geofence_state_store.dart';
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
  // Walk-test logs (2026-11-04) showed a stationary phone's fixes jumping
  // between ~490m and ~545m from the same shop with reported accuracy of only
  // 6-16m, so a 30m buffer flapped ENTER/EXIT every 10-30s for 15 minutes.
  static const double _minExitBufferMeters = 75;
  // A single stray fix (good reported accuracy, bad real position -- common
  // indoors with multipath) shouldn't be enough to flip a transition. Require
  // this many *distinct* consecutive fixes to agree before firing.
  static const int _confirmationCount = 2;
  // How long "inside" is remembered after it was last confirmed, for shops
  // that drop out of a fetch or across an app restart -- otherwise both
  // re-fire ENTER for shops the user never left.
  static const Duration _insideMemory = Duration(minutes: 30);
  static const Duration _minPersistInterval = Duration(minutes: 1);

  final LocationService _locationService;
  final GeofenceStateStore _stateStore;
  final Map<String, ShopLocation> _geofenceData = {};

  // identifier -> when the user was last confirmed inside it. Its keys are the
  // "inside" set; entries for shops no longer tracked expire after
  // [_insideMemory].
  final Map<String, DateTime> _lastInsideAt = {};
  final Map<String, int> _pendingEnterCounts = {};
  final Map<String, int> _pendingExitCounts = {};
  // identifier -> signature of the last fix counted towards a confirmation.
  final Map<String, String> _lastCountedFix = {};
  DateTime? _lastPersistedAt;
  bool _persistScheduled = false;

  final _geofenceEventController = StreamController<AppGeofenceEvent>.broadcast();

  Stream<AppGeofenceEvent> get onGeofenceEvent => _geofenceEventController.stream;

  Map<String, ShopLocation> get geofenceData => Map.unmodifiable(_geofenceData);

  Set<String> get activeGeofenceIdentifiers =>
      Set.unmodifiable(_lastInsideAt.keys.toSet());

  GeofenceService({
    required LocationService locationService,
    GeofenceStateStore? stateStore,
  }) : _locationService = locationService,
       _stateStore = stateStore ?? GeofenceStateStore() {
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

    // The process may have been killed in the background (MIUI does this);
    // restore which shops the user was recently inside so the first fetch
    // after a restart doesn't re-fire ENTER for all of them.
    final cutoff = DateTime.now().subtract(_insideMemory);
    final restored = await _stateStore.load();
    restored.removeWhere((_, lastInside) => lastInside.isBefore(cutoff));
    _lastInsideAt.addAll(restored);
    DebugFileLogger().log('GeofenceService.initialize restored ${restored.length} inside entries');
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
        // _lastInsideAt is deliberately kept: shops can drop out of a single
        // fetch and come back in the next one while the user never moved.
        _pendingEnterCounts.remove(identifier);
        _pendingExitCounts.remove(identifier);
        _lastCountedFix.remove(identifier);
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
    final now = DateTime.now();

    _lastInsideAt.removeWhere(
      (identifier, lastInside) =>
          !_geofenceData.containsKey(identifier) &&
          now.difference(lastInside) > _insideMemory,
    );

    for (final entry in _geofenceData.entries) {
      final identifier = entry.key;
      final shop = entry.value;
      final distance = calculateDistance(
        userPosition,
        LatLng(shop.latitude, shop.longitude),
      );
      final wasInside = _lastInsideAt.containsKey(identifier);

      if (!wasInside) {
        _pendingExitCounts.remove(identifier);
        if (distance <= _geofenceRadiusMeters) {
          if (!_isNewFix(identifier, userLocation)) continue;
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
          if (!_isNewFix(identifier, userLocation)) continue;
          final count = (_pendingExitCounts[identifier] ?? 0) + 1;
          if (count >= _confirmationCount) {
            _pendingExitCounts.remove(identifier);
            _emitSoftwareGeofenceEvent(identifier, GeofenceAction.exit);
          } else {
            _pendingExitCounts[identifier] = count;
          }
        } else {
          _pendingExitCounts.remove(identifier);
          _lastInsideAt[identifier] = now;
        }
      }
    }
    _persistInsideState(force: false);
  }

  /// False when this exact fix already counted towards a confirmation for
  /// [identifier] -- the same fix is re-checked right after [addGeofences],
  /// and Tracelet re-emits the last position as a new record (new timestamp,
  /// identical coordinates and accuracy) e.g. after getCurrentLocation(),
  /// which used to let a single fix count as both confirmations. Compared by
  /// position + accuracy, since a genuinely new fix is never bit-identical.
  bool _isNewFix(String identifier, AppLocation location) {
    final signature = '${location.latitude},${location.longitude},${location.accuracy}';
    if (_lastCountedFix[identifier] == signature) return false;
    _lastCountedFix[identifier] = signature;
    return true;
  }

  void _persistInsideState({required bool force}) {
    final now = DateTime.now();
    final lastPersistedAt = _lastPersistedAt;
    if (!force &&
        lastPersistedAt != null &&
        now.difference(lastPersistedAt) < _minPersistInterval) {
      return;
    }
    _lastPersistedAt = now;
    _stateStore.save(Map.of(_lastInsideAt));
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
    _applyTransition(identifier, action);
    notifyListeners();
  }

  void _applyTransition(String identifier, GeofenceAction action) {
    if (action == GeofenceAction.enter) {
      _lastInsideAt[identifier] = DateTime.now();
    } else if (action == GeofenceAction.exit) {
      _lastInsideAt.remove(identifier);
    } else {
      return;
    }
    // Deferred to the end of the current event-loop turn so an ENTER burst
    // (one per shop, all from the same _checkProximity pass) saves once.
    if (!_persistScheduled) {
      _persistScheduled = true;
      scheduleMicrotask(() {
        _persistScheduled = false;
        _persistInsideState(force: true);
      });
    }
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
    // _lastInsideAt survives on purpose (see _insideMemory); it expires by
    // itself once these shops stay untracked for long enough.
    _pendingEnterCounts.clear();
    _pendingExitCounts.clear();
    _lastCountedFix.clear();
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
    _applyTransition(event.identifier, action);
    notifyListeners();
  }
}
