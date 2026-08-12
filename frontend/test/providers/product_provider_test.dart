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

  test('addProduct correctly trims and normalizes name for new products', () async {
    // ARRANGE
    const productNameWithExtras = '  ?Another Test Product!  ';
    const expectedNormalizedName = 'Another Test Product';
    final newProductList = [Product(id: 1, name: expectedNormalizedName)];

    // Ensure initial load is empty or doesn't contain the product
    when(mockProductRepository.getAllProducts()).thenAnswer((_) async => []);
    await productProvider.loadInitialData(); // Initial call to getAllProducts

    // Setup for the getAllProducts call after addProduct
    when(mockProductRepository.getAllProducts()).thenAnswer((_) async => newProductList);

    // ACT
    await productProvider.addProduct(productNameWithExtras);

    // ASSERT
    // Verify addProduct was called on the repository with the normalized name
    verify(
      mockProductRepository.addProduct(
        argThat(predicate<Product>((p) => p.name == expectedNormalizedName)),
      ),
    ).called(1);

    // Verify getAllProducts was called again to refresh the list
    verify(mockProductRepository.getAllProducts()).called(2); // Initial load + after add

    // Verify the product list in the provider is updated with the normalized name
    expect(productProvider.products.length, 1);
    expect(productProvider.products.first.name, expectedNormalizedName);
  });

  group('Category lookup and categorized add', () {
    test('lookupCategory returns the category from the repository', () async {
      // ARRANGE
      when(
        mockProductRepository.getProductCategory('ciocan'),
      ).thenAnswer((_) async => 'hardware_store');

      // ACT
      final result = await productProvider.lookupCategory('ciocan');

      // ASSERT
      expect(result, 'hardware_store');
    });

    test('lookupCategory returns null when the product is uncategorized', () async {
      // ARRANGE
      when(
        mockProductRepository.getProductCategory('unobtainium'),
      ).thenAnswer((_) async => null);

      // ACT
      final result = await productProvider.lookupCategory('unobtainium');

      // ASSERT
      expect(result, isNull);
    });

    test('addProductWithCategory saves the category then adds the product', () async {
      // ARRANGE
      const productName = 'Ciocan';
      when(
        mockProductRepository.saveProductCategory(productName, 'hardware_store'),
      ).thenAnswer((_) async {});
      when(mockProductRepository.getAllProducts()).thenAnswer((_) async => []);
      await productProvider.loadInitialData();
      when(
        mockProductRepository.getAllProducts(),
      ).thenAnswer((_) async => [Product(id: 1, name: productName)]);

      // ACT
      await productProvider.addProductWithCategory(productName, 'hardware_store');

      // ASSERT
      verify(mockProductRepository.saveProductCategory(productName, 'hardware_store')).called(1);
      verify(
        mockProductRepository.addProduct(
          argThat(predicate<Product>((p) => p.name == productName)),
        ),
      ).called(1);
    });
  });
}
