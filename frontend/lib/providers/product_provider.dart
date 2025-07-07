import 'dart:collection';
import 'dart:developer';

import 'package:flutter/cupertino.dart';
import 'package:frontend/models/product.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/services/database_service.dart';
import 'package:frontend/services/location_service.dart';

class ProductProvider extends ChangeNotifier{
  //instantiate our services
  final DatabaseService _databaseService = DatabaseService();
  final APiService _aPiService = APiService();
  final LocationService _locationService = LocationService();

  List<Product> _products = [];

  //public getter for product list.
  //unmodifiable view - UI can't change the list directly.
  UnmodifiableListView<Product> get products => UnmodifiableListView(_products);

  ProductProvider(){
    _initialize();
  }

  Future<void> _initialize() async{
    //initialize location service as soon as app starts
    await _locationService.initialize();
    //load the initial list of products from db.
    await fetchProducts();
  }

  Future<void> fetchProducts() async{
    _products = await _databaseService.getProducts();
    log('Fetched ${_products.length} products from the database.', name: 'ProductProvider');
    notifyListeners(); //notify the ui the list has changed
    _updateGeofences(); //update geofences when productlist is loaded
  }

  Future<void> _updateGeofences()async{
    if(products.isEmpty){
      log('No products, clearing all geofences.', name: 'ProductProvider');
      //ToDo: clearGeofencesMethod and call it here.
      return;
    }

    log('Updating geofences for ${_products.length} products.', name: 'ProductProvider');
    final locations = await _aPiService.findShops(products);
    if(locations.isNotEmpty){
      await _locationService.addGeofences(locations);
    }
  }

  Future<void> addProduct(String name) async {
      if (name.isEmpty) return;
      final newProduct = Product(name: name);
      await _databaseService.addProduct(newProduct);
      log('Added product: $name', name: 'ProductProvider');
      await fetchProducts(); // Re-fetch the list from the DB to get the new ID.
    }

  Future<void> deleteProduct(int id) async {
      await _databaseService.deleteProduct(id);
      log('Deleted product with id: $id', name: 'ProductProvider');
      await fetchProducts(); // Re-fetch the list to reflect the deletion.
    }

}