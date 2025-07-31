import 'dart:collection';
import 'dart:developer';

import 'package:buy_beacon/models/product.dart';
import 'package:buy_beacon/models/shop_location.dart';
import 'package:buy_beacon/services/api_service.dart';
import 'package:buy_beacon/services/database_service.dart';
import 'package:buy_beacon/services/location_service.dart';
import 'package:diacritic/diacritic.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class ProductProvider extends ChangeNotifier {
  //instantiate our services
  final DatabaseService _databaseService;
  final ApiService _apiService;
  final LocationService _locationService;

  List<Product> _products = [];
  List<ShopLocation> _shopLocations = [];
  bool _isInitialized = false;
  bool _isUpdatingGeofences = false;

  //public getter for product list.
  //unmodifiable view - UI can't change the list directly.
  UnmodifiableListView<Product> get products => UnmodifiableListView(_products);

  UnmodifiableListView<ShopLocation> get shopLocations =>
      UnmodifiableListView(_shopLocations);

  bool get isInitialized => _isInitialized;

  bool get isUpdatingGeofences => _isUpdatingGeofences;

  ProductProvider({
    DatabaseService? dbService,
    ApiService? api,
    LocationService? location,
    void Function(NotificationResponse response)? onNotificationTap,
  }) : _databaseService = dbService ?? DatabaseService(),
       _apiService = api ?? ApiService(),
       _locationService = location ?? LocationService() {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      //initialize location service as soon as app starts
      log('[ProductProvider] Initializing LocationService...', name: 'ProductProvider');
      await _locationService.initialize();
      log(
        '[ProductProvider] LocationService initialized successfully.',
        name: 'ProductProvider',
      );

      //load the initial list of products from db.
      log('[ProductProvider] Fetching initial products...', name: 'ProductProvider');
      await fetchProducts();
      log(
        '[ProductProvider] Initial products fetched successfully.',
        name: 'ProductProvider',
      );

      _isInitialized = true;
      log('[ProductProvider] Initialization COMPLETE.', name: 'ProductProvider');
    } catch (e, stackTrace) {
      log(
        '[ProductProvider] CRITICAL ERROR DURING INITIALIZATION',
        name: 'ProductProvider',
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      notifyListeners();
    }
  }

  Future<void> fetchProducts() async {
    _products = await _databaseService.getProducts();
    log(
      'Fetched ${_products.length} products from the database.',
      name: 'ProductProvider',
    );
    notifyListeners(); //notify the ui the list has changed
    _updateGeofences(); //update geofences in the background when productlist is loaded
  }

  Future<void> _updateGeofences() async {
    try {
      _isUpdatingGeofences = true;
      notifyListeners();

      if (products.isEmpty) {
        log('No products, clearing all geofences.', name: 'ProductProvider');
        await _locationService.clearGeoFences();
        _shopLocations = [];
        notifyListeners();
        return;
      }
      log(
        'Updating geofences for ${_products.length} products.',
        name: 'ProductProvider',
      );
      try {
        final locations = await _apiService.findShops(products);
        _shopLocations = locations;
        if (locations.isNotEmpty) {
          await _locationService.addGeofences(locations);
        }
      } catch (e, s) {
        log(
          'Failed to update geofences from API. The device may be offline.',
          name: 'ProductProvider',
          error: e,
          stackTrace: s,
        );
      }
    } finally {
      _isUpdatingGeofences = false;
      notifyListeners();
    }
  }

  String _normalizedString(String product) {
    String trimmed = product.trim();
    String noPunctuation = trimmed.replaceAll(
      RegExp(r'^[^\p{L}\p{N}]+|[^\p{L}\p{N}]+$'),
      '',
    );
    return removeDiacritics(noPunctuation).trim().toLowerCase();
  }

  Future<void> addProduct(String name) async {
    final normalizedName = _normalizedString(name);
    if (normalizedName.isEmpty) return;

    final isDuplicate = _products.any((p) => _normalizedString(p.name) == normalizedName);

    if (isDuplicate) {
      log(
        'Product "$name" (normalized: "$normalizedName") already exists in the list.',
        name: 'ProductProvider',
      );
      return;
    }
    try {
      final newProduct = Product(name: name.trim());
      await _databaseService.addProduct(newProduct);
      log('Added product: ${name.trim()}', name: 'ProductProvider');
      await fetchProducts(); // Re-fetch the list from the DB to get the new ID.
    } catch (e, s) {
      log(
        'Error in addProduct. The product was saved locally, but failed to update geofences.',
        name: 'ProductProvider',
        error: e,
        stackTrace: s,
      );
    }
  }

  Future<void> deleteProduct(int id) async {
    try {
      await _databaseService.deleteProduct(id);
      log('Deleted product with id: $id', name: 'ProductProvider');
      await fetchProducts(); // Re-fetch the list to reflect the deletion.
    } catch (e, s) {
      log(
        'Error in deleteProduct. The product was deleted locally, but failed to update geofences.',
        name: 'ProductProvider',
        error: e,
        stackTrace: s,
      );
    }
  }
}
