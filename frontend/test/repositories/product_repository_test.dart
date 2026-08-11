import 'package:buy_beacon/models/product.dart';
import 'package:buy_beacon/repositories/product_repository.dart';
import 'package:buy_beacon/services/api_service.dart';
import 'package:buy_beacon/services/database_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'product_repository_test.mocks.dart';

@GenerateMocks([DatabaseService, ApiService])
void main() {
  late ProductRepository productRepository;
  late MockDatabaseService mockDatabaseService;
  late MockApiService mockApiService;

  setUp(() {
    mockDatabaseService = MockDatabaseService();
    mockApiService = MockApiService();
    productRepository = ProductRepository(
      databaseService: mockDatabaseService,
      apiService: mockApiService,
    );
  });

  group('ProductRepository', () {
    test('getAllProducts should call DatabaseService.getProducts', () async {
      //ARRANGE
      when(mockDatabaseService.getProducts()).thenAnswer((_) async => []);

      //ACT
      await productRepository.getAllProducts();

      //ASSERT
      verify(mockDatabaseService.getProducts()).called(1);
    });

    test('addProduct should call DatabaseService.addProduct', () async {
      //ARRANGE
      final product = Product(id: 1, name: 'Test product');
      when(mockDatabaseService.addProduct(product)).thenAnswer((_) async => 1);

      //ACT
      await productRepository.addProduct(product);

      //ASSERT
      verify(mockDatabaseService.addProduct(product)).called(1);
    });

    test('deleteProduct should call DatabeseService.deleteProduct', () async {
      //ARRANGE
      when(mockDatabaseService.deleteProduct(1)).thenAnswer((_) async => 1);
      //ACT
      await mockDatabaseService.deleteProduct(1);

      //ASSERT
      verify(mockDatabaseService.deleteProduct(1)).called(1);
    });

    test('findShopsForProducts should call ApiService.findShops', () async {
      //ARRANGE
      final products = [Product(name: 'Test product')];
      when(mockApiService.findShops(products)).thenAnswer((_) async => []);
      //ACT
      await productRepository.findShopsForProducts(products);

      //ASSERT
      verify(mockApiService.findShops(products)).called(1);
    });

    test('findShopsForProducts should return empty list if products are empty', () async {
      //ARRANGE

      //ACT
      final result = await productRepository.findShopsForProducts([]);

      //ASSERT
      expect(result, isEmpty);
      verifyNever(mockApiService.findShops(any));
    });
  });
}
