import 'package:buy_beacon/models/product.dart';
import 'package:buy_beacon/providers/product_provider.dart';
import 'package:buy_beacon/repositories/product_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'product_provider_test.mocks.dart';

@GenerateMocks([ProductRepository])
void main() {
  // TestWidgetsFlutterBinding.ensureInitialized();

  late ProductProvider productProvider;
  late MockProductRepository mockProductRepository;

  setUp(() {
    mockProductRepository = MockProductRepository();
    productProvider = ProductProvider(productRepository: mockProductRepository);

    when(mockProductRepository.addProduct(any)).thenAnswer((_) async => {});
  });

  group('Product Provider logic', () {
    test('loadInitialData fetches products and sets isInitialized', () async {
      //ARRANGE
      when(mockProductRepository.getAllProducts()).thenAnswer((_) async => []);

      //ACT
      await productProvider.loadInitialData();

      //ASSERT
      verify(mockProductRepository.getAllProducts()).called(1);
      expect(productProvider.isInitialized, true);
    });

    test('addProduct calls repository and updates the local product list', () async {
      //ARRANGE
      const productName = 'Test Coffee';
      final newProductList = [Product(id: 1, name: productName)];

      when(mockProductRepository.getAllProducts()).thenAnswer((_) async => []);
      await productProvider.loadInitialData();

      when(
        mockProductRepository.getAllProducts(),
      ).thenAnswer((_) async => newProductList);

      //ACT
      await productProvider.addProduct(productName);

      //ASSERT
      verify(
        mockProductRepository.addProduct(
          argThat(predicate<Product>((p) => p.name == productName)),
        ),
      ).called(1);

      verify(mockProductRepository.getAllProducts()).called(2);

      expect(productProvider.products, newProductList);
    });

    test('deleteProduct calls repository and updates the local product list', () async {
      //ARRANGE
      const productId = 1;
      final initialProductList = [Product(id: productId, name: 'Test')];

      when(
        mockProductRepository.getAllProducts(),
      ).thenAnswer((_) async => initialProductList);

      await productProvider.loadInitialData();

      when(mockProductRepository.getAllProducts()).thenAnswer((_) async => []);
      when(mockProductRepository.deleteProduct(any)).thenAnswer((_) async {});

      // ACT
      await productProvider.deleteProduct(productId);

      // ASSERT
      verify(mockProductRepository.deleteProduct(productId)).called(1);
      verify(mockProductRepository.getAllProducts()).called(2);

      expect(productProvider.products, isEmpty);
    });
  });

  test(
    'addProduct does not add duplicate products case-insensitive, untrimmed, trailing and leading punctuation',
    () async {
      // ARRANGE
      const productName = 'Test Coffee';
      // 1. Initial load already contains the product.
      when(
        mockProductRepository.getAllProducts(),
      ).thenAnswer((_) async => [Product(name: productName)]);
      await productProvider.loadInitialData();

      // ACT
      // Attempt to add the same product again (case-insensitive).
      await productProvider.addProduct('? test coffee. :');

      // ASSERT
      // Verify that addProduct was NEVER called on the repository.
      verifyNever(mockProductRepository.addProduct(any));
      // Verify that getAllProducts was only called once during the initial load.
      verify(mockProductRepository.getAllProducts()).called(1);
    },
  );
}
