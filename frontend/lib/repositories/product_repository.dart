import 'package:buy_beacon/models/product.dart';
import 'package:buy_beacon/models/shop_location.dart';
import 'package:buy_beacon/services/api_service.dart';
import 'package:buy_beacon/services/database_service.dart';

class ProductRepository {
  final DatabaseService _databaseService;
  final ApiService _apiService;

  ProductRepository({DatabaseService? databaseService, ApiService? apiService})
    : _databaseService = databaseService ?? DatabaseService(),
      _apiService = apiService ?? ApiService();

  Future<List<Product>> getAllProducts() {
    return _databaseService.getProducts();
  }

  Future<void> addProduct(Product product) {
    return _databaseService.addProduct(product);
  }

  Future<void> deleteProduct(int id) {
    return _databaseService.deleteProduct(id);
  }

  Future<List<ShopLocation>> findShopsForProducts(
    List<Product> products, {
    double? latitude,
    double? longitude,
  }) {
    if (products.isEmpty) {
      return Future.value([]);
    }
    return _apiService.findShops(products, latitude: latitude, longitude: longitude);
  }
}
