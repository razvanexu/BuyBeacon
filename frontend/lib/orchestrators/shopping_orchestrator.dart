import 'dart:async';
import 'dart:developer';
import 'dart:math' hide log;

import 'package:buy_beacon/orchestrators/shopping_state.dart';
import 'package:buy_beacon/providers/product_provider.dart';
import 'package:buy_beacon/repositories/product_repository.dart';
import 'package:buy_beacon/services/geofence_service.dart';
import 'package:buy_beacon/services/location_service.dart';

class ShoppingOrchestrator {
  final ProductProvider _productProvider;
  final ProductRepository _productRepository;
  final GeofenceService _geofenceService;
  final LocationService _locationService;

  final _controller = StreamController<ShoppingState>.broadcast();

  Stream<ShoppingState> get onStateChanged => _controller.stream;

  ShoppingState _state = ShoppingState();

  ShoppingState get currentState => _state;

  Timer? _retryTimer;
  int _retryAttempt = 0;
  static const Duration _initialRetryDelay = Duration(seconds: 30);
  static const Duration _maxRetryDelay = Duration(hours: 1);

  ShoppingOrchestrator({
    required ProductProvider productProvider,
    required ProductRepository productRepository,
    required GeofenceService geofenceService,
    required LocationService locationService,
  }) : _productProvider = productProvider,
       _productRepository = productRepository,
       _geofenceService = geofenceService,
       _locationService = locationService {
    _productProvider.onProductsChanged = _onProductsChanged;
  }

  Future<void> _onProductsChanged() async {
    _cancelRetryTimer();
    await _fetchProductsAndShops();
  }

  Future<void> _fetchProductsAndShops() async {
    log(
      '[ShoppingOrchestrator] _fetchProductsAndShops called.',
      name: 'ShoppingOrchestrator',
    );
    // _emitState(isLoading: true);
    _state = _state.copyWith(isLoading: true, hasConnectionError: false);
    _controller.add(_state);
    try {
      final products = _productProvider.products;

      if (_productProvider.products.isEmpty) {
        log(
          '[ShoppingOrchestrator] Product list is empty. Clearing geofences.',
          name: 'ShoppingOrchestrator',
        );
        await _geofenceService.addGeofences([]);
        _state = _state.copyWith(shopLocations: [], hasConnectionError: false);
        _emitState(isLoading: false);
        return;
      }
      log(
        '[ShoppingOrchestrator] Fetching shops for ${products.length} products.',
        name: 'ShoppingOrchestrator',
      );

      final currentLocation =
          _locationService.userLocation ?? await _locationService.getCurrentLocation();

      final shopLocations = await _productRepository.findShopsForProducts(
        products.toList(),
        latitude: currentLocation?.coords.latitude,
        longitude: currentLocation?.coords.longitude,
      );
      log(
        '[ShoppingOrchestrator] Fetched ${shopLocations.length} shop locations. Now adding geofences.',
        name: 'ShoppingOrchestrator',
      );
      await _geofenceService.addGeofences(shopLocations);

      log(
        '[ShoppingOrchestrator] Finished calling addGeofences.',
        name: 'ShoppingOrchestrator',
      );

      _state = _state.copyWith(shopLocations: shopLocations, hasConnectionError: false);
      _cancelRetryTimer();
    } catch (e, s) {
      log(
        '[ShoppingOrchestrator] EXECUTION: Entered CATCH block in _fetchProductsAndShops!',
      );
      log(
        'Failed to update shops or geofences',
        name: 'ShoppingOrchestrator',
        error: e,
        stackTrace: s,
      );
      _state = _state.copyWith(hasConnectionError: true);
      log(
        '[ShoppingOrchestrator] State updated in CATCH block: hasConnectionError = ${_state.hasConnectionError}, isLoading = ${_state.isLoading}',
      );
      _scheduleRetry();
    } finally {
      log(
        '[ShoppingOrchestrator] State BEFORE emit in FINALLY: hasConnectionError = ${_state.hasConnectionError}',
      );
      _emitState(isLoading: false);
    }
  }

  void _scheduleRetry() {
    _cancelRetryTimer();
    _retryAttempt++;

    final delayInSeconds = _initialRetryDelay.inSeconds * pow(2, _retryAttempt);
    final cappedDelay = Duration(
      seconds: min(delayInSeconds.toInt(), _maxRetryDelay.inSeconds),
    );

    log(
      'Scheduling retry attempt #$_retryAttempt in ${cappedDelay.inMinutes} minutes.',
      name: 'ShoppingOrchestrator',
    );

    _retryTimer = Timer(cappedDelay, () {
      log('Executing retry attempt #$_retryAttempt.', name: 'ShoppingOrchestrator');
      _fetchProductsAndShops();
    });
  }

  void _cancelRetryTimer() {
    if (_retryTimer?.isActive ?? false) {
      _retryTimer!.cancel();
      log('Retry timer cancelled.', name: 'ShoppingOrchestrator');
    }
    _retryAttempt = 0;
  }

  void _emitState({bool? isLoading}) {
    if (isLoading != null) {
      _state = _state.copyWith(isLoading: isLoading);
    }
    log(
      '[ShoppingOrchestrator] Emitting state in _emitState: hasConnectionError = ${_state.hasConnectionError}, isLoading = ${_state.isLoading}',
    );
    _controller.add(_state);
  }

  void dispose() {
    _controller.close();
    _cancelRetryTimer();
    _productProvider.onProductsChanged = null;
  }
}
