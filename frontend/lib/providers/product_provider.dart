import 'dart:collection';
import 'dart:developer';

import 'package:buy_beacon/models/category_option.dart';
import 'package:buy_beacon/models/product.dart';
import 'package:buy_beacon/repositories/product_repository.dart';
import 'package:flutter/cupertino.dart';

/// Manages the application state for the product list.
///
/// This provider is responsible for holding the list of products,
/// handling user actions (add, delete), and delegating data operations
/// to the [ProductRepository].
class ProductProvider extends ChangeNotifier {
  //instantiate our repository
  final ProductRepository _productRepository;

  List<Product> _products = [];
  bool _isInitialized = false;

  VoidCallback? onProductsChanged;

  //public getter for product list.
  //unmodifiable view - UI can't change the list directly.
  UnmodifiableListView<Product> get products => UnmodifiableListView(_products);

  bool get isInitialized => _isInitialized;

  ProductProvider({required ProductRepository productRepository})
    : _productRepository = productRepository;

  Future<void> loadInitialData() async {
    if (_isInitialized) return; // Prevent multiple initializations
    _products = await _productRepository.getAllProducts();
    _isInitialized = true;
    notifyListeners();
    onProductsChanged?.call();
  }

  Future<void> addProduct(String name) async {
    final normalizedName = Product.normalizeName(name);
    if (normalizedName.isEmpty) {
      return;
    }

    final isDuplicate = _products.any(
      (p) => Product.normalizeName(p.name.toLowerCase()) == normalizedName.toLowerCase(),
    );

    if (isDuplicate) {
      log('Product "$name" (normalized: "$normalizedName") already exists in the list.');
      return;
    }
    try {
      final newProduct = Product(name: normalizedName.trim());
      await _productRepository.addProduct(newProduct);
      _products = await _productRepository
          .getAllProducts(); // Re-fetch the list from the DB to get the new ID.
      notifyListeners();
      onProductsChanged?.call();
    } catch (e, s) {
      log(
        'Error in addProduct. The product was saved locally, but failed to update geofences.',
        name: 'ProductProvider',
        error: e,
        stackTrace: s,
      );
    }
  }

  /// Looks up the crowdsourced category for a product name. Returns null if
  /// the product isn't categorized yet — the caller should prompt the user
  /// with [getCategoryOptions] and then call [addProductWithCategory].
  Future<String?> lookupCategory(String name) {
    return _productRepository.getProductCategory(name);
  }

  /// The fixed, closed list of categories a user can pick from when a
  /// product isn't categorized yet.
  Future<List<CategoryOption>> getCategoryOptions() {
    return _productRepository.getCategoryOptions();
  }

  /// Submits a category for a previously-uncategorized product, then adds it
  /// via the normal [addProduct] flow.
  Future<void> addProductWithCategory(String name, String category) async {
    await _productRepository.saveProductCategory(name, category);
    await addProduct(name);
  }

  Future<void> deleteProduct(int id) async {
    try {
      await _productRepository.deleteProduct(id);
      log('Deleted product with id: $id', name: 'ProductProvider');
      _products = await _productRepository
          .getAllProducts(); // Re-fetch the list to reflect the deletion.
      notifyListeners();
      onProductsChanged?.call();
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
