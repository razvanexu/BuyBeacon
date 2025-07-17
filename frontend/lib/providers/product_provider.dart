import 'dart:collection';
import 'dart:developer';

import 'package:flutter/cupertino.dart';
import 'package:frontend/models/product.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/services/database_service.dart';
import 'package:frontend/services/location_service.dart';

class ProductProvider extends ChangeNotifier{
  //instantiate our services
  final DatabaseService _databaseService;
  final ApiService _apiService;
  final LocationService _locationService;

  List<Product> _products = [];

  //public getter for product list.
  //unmodifiable view - UI can't change the list directly.
  UnmodifiableListView<Product> get products => UnmodifiableListView(_products);

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;


  ProductProvider({
    DatabaseService? dbService,
    ApiService? api,
    LocationService? location
}) : _databaseService = dbService ?? DatabaseService(),
     _apiService = api ?? ApiService(),
     _locationService = location ?? LocationService(){
    _initialize();
  }

  Future<void> _initialize() async{
    try{
    //initialize location service as soon as app starts
    log('[ProductProvider] Initializing LocationService...', name: 'ProductProvider');
    await _locationService.initialize();
    log('[ProductProvider] LocationService initialized successfully.', name: 'ProductProvider');

    //load the initial list of products from db.
    log('[ProductProvider] Fetching initial products...', name: 'ProductProvider');
    await fetchProducts();
    log('[ProductProvider] Initial products fetched successfully.', name: 'ProductProvider');

    _isInitialized = true;
    log('[ProductProvider] Initialization COMPLETE.', name: 'ProductProvider');
    }catch(e, stackTrace){
      log(
          '[ProductProvider] CRITICAL ERROR DURING INITIALIZATION',
        name: 'ProductProvider',
        error: e,
        stackTrace: stackTrace
      );
    }finally{
      notifyListeners();
    }
  }

  Future<void> fetchProducts() async{
    _products = await _databaseService.getProducts();
    log('Fetched ${_products.length} products from the database.', name: 'ProductProvider');
    notifyListeners(); //notify the ui the list has changed
    await _updateGeofences(); //update geofences when productlist is loaded
  }


  Future<void> _updateGeofences()async{
    if(products.isEmpty){
      log('No products, clearing all geofences.', name: 'ProductProvider');
      await _locationService.clearGeoFences();
      return;
    }

    log('Updating geofences for ${_products.length} products.', name: 'ProductProvider');
    final locations = await _apiService.findShops(products);
    if(locations.isNotEmpty){
      await _locationService.addGeofences(locations);
    }
  }

  Future<void> addProduct(String name) async {
      if (name.isEmpty) return;

      final isDuplicate = _products.any((p) => p.name.toLowerCase() == name.toLowerCase());
      if(isDuplicate){
        log('Product "$name" already exists in the list.', name: 'ProductProvider');
        return;

      }
      try{
        final newProduct = Product(name: name);
        await _databaseService.addProduct(newProduct);
        log('Added product: $name', name: 'ProductProvider');
        await fetchProducts(); // Re-fetch the list from the DB to get the new ID.
      }catch(e, s){
        log('Error in addProduct. The product was saved locally, but failed to update geofences.', name: 'ProductProvider', error: e, stackTrace: s);
      }
    }

  Future<void> deleteProduct(int id) async {
    try{
      await _databaseService.deleteProduct(id);
      log('Deleted product with id: $id', name: 'ProductProvider');
      await fetchProducts(); // Re-fetch the list to reflect the deletion.
    }catch(e, s){
      log('Error in deleteProduct. The product was deleted locally, but failed to update geofences.', name: 'ProductProvider', error: e, stackTrace: s);
    }
  }

}