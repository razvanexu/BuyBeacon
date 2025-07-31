import 'package:buy_beacon/models/product.dart';
import 'package:buy_beacon/models/shop_location.dart';
import 'package:buy_beacon/providers/product_provider.dart';
import 'package:buy_beacon/services/api_service.dart';
import 'package:buy_beacon/services/database_service.dart';
import 'package:buy_beacon/services/location_service.dart';
import 'package:buy_beacon/services/notification_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'product_provider_test.mocks.dart';

@GenerateMocks([
  DatabaseService,
  ApiService,
  LocationService,
  ProductProvider,
  NotificationService,
])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProductProvider productProvider;
  late MockDatabaseService mockDatabaseService;
  late MockApiService mockApiService;
  late MockLocationService mockLocationService;

  const MethodChannel channel = MethodChannel(
    'com.transistorsoft/flutter_background_geolocation/methods',
  );

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          switch (methodCall.method) {
            case 'addGeofence':
            case 'addGeofences':
            case 'removeGeofences':
            case 'clearGeofences':
            case 'startGeofences':
              return true;
            case 'ready':
              return {'enabled': true, 'trackingMode': 1};
            default:
              return null;
          }
        });
  });

  setUp(() {
    mockDatabaseService = MockDatabaseService();
    mockApiService = MockApiService();
    mockLocationService = MockLocationService();

    when(mockLocationService.initialize()).thenAnswer((_) async {});
    when(mockLocationService.addGeofences(any)).thenAnswer((_) async {});
    when(mockLocationService.clearGeoFences()).thenAnswer((_) async {});
    when(mockApiService.findShops(any)).thenAnswer((_) async => []);
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('Product Management', () {
    test('Initial state is correct after async initialization', () async {
      //ARRANGE
      when(mockDatabaseService.getProducts()).thenAnswer((_) async => []);

      //ACT
      final productProvider = ProductProvider(
        dbService: mockDatabaseService,
        api: mockApiService,
        location: mockLocationService,
      );
      await Future.delayed(Duration.zero);

      //Assert
      verify(mockLocationService.initialize()).called(1);
      verify(mockDatabaseService.getProducts()).called(1);
      expect(productProvider.isInitialized, isTrue);
      expect(productProvider.products, isEmpty);
    });

    test('addProduct should add product, refetch list, and update geofences', () async {
      // ARRANGE phase 1
      const productName = 'Test Coffee';
      final newProduct = Product(id: 1, name: productName);
      final shopLocation = ShopLocation(
        name: 'Coffee Place',
        latitude: 1.0,
        longitude: 1.0,
        products: [productName],
      );

      // 1. Set up the mock for the FIRST call to getProducts (during initialization)
      when(mockDatabaseService.getProducts()).thenAnswer((_) async => []);
      // Mock the sequence of events for adding a product.
      when(mockDatabaseService.addProduct(any)).thenAnswer((_) async => 1);
      // When findShops is called with the new product list, return a location.
      when(mockApiService.findShops(any)).thenAnswer((_) async => [shopLocation]);

      //ACT phase 1 - initialization
      productProvider = ProductProvider(
        dbService: mockDatabaseService,
        api: mockApiService,
        location: mockLocationService,
      );
      await Future.delayed(Duration.zero);

      //ARRANGE phase 2
      when(mockDatabaseService.getProducts()).thenAnswer((_) async => [newProduct]);

      //ACT phase 2
      await productProvider.addProduct(productName);
      await untilCalled(mockLocationService.addGeofences(any));

      //ASSERT
      verify(
        mockDatabaseService.addProduct(
          argThat(predicate<Product>((p) => p.name == productName)),
        ),
      ).called(1);
      //getProducts() is called twice - once on init and once after adding
      verify(mockDatabaseService.getProducts()).called(2);
      expect(productProvider.products.length, 1);
      expect(productProvider.products.first.name, productName);

      verify(mockApiService.findShops(any)).called(1);
      verify(mockLocationService.addGeofences(any)).called(1);

      verify(mockLocationService.clearGeoFences()).called(1);
    });

    test(
      'deleteProduct should remove product, refetch list, and clear geofences',
      () async {
        //ARRANGE
        final productToDelete = Product(id: 1, name: 'Old Product');
        when(
          mockDatabaseService.getProducts(),
        ).thenAnswer((_) async => [productToDelete]);

        final productProvider = ProductProvider(
          dbService: mockDatabaseService,
          api: mockApiService,
          location: mockLocationService,
        );
        await Future.delayed(Duration.zero);

        when(mockDatabaseService.deleteProduct(1)).thenAnswer((_) async => 1);
        when(mockDatabaseService.getProducts()).thenAnswer((_) async => []);

        //ACT
        await productProvider.deleteProduct(1);

        //ASSERT
        verify(mockDatabaseService.deleteProduct(1)).called(1);
        verify(mockDatabaseService.getProducts()).called(2);
        expect(productProvider.products, isEmpty);
        verify(mockLocationService.clearGeoFences()).called(1);
      },
    );

    test('addProduct should still succeed locally even if ApiService fails', () async {
      //ARRANGE phase 1
      const productName = 'Network-Fail Product';
      final newProduct = Product(id: 1, name: productName);

      when(mockDatabaseService.getProducts()).thenAnswer((_) async => []);
      when(mockDatabaseService.addProduct(any)).thenAnswer((_) async => 1);
      when(
        mockApiService.findShops(any),
      ).thenThrow(Exception('Network Error: 503 Service Unavailable'));

      //ACT phase 1
      final productProvider = ProductProvider(
        dbService: mockDatabaseService,
        api: mockApiService,
        location: mockLocationService,
      );
      await Future.delayed(Duration.zero);

      //ARRANGE phase 2
      when(mockDatabaseService.getProducts()).thenAnswer((_) async => [newProduct]);

      //ACT phase 2
      await productProvider.addProduct(productName);
      await untilCalled(mockApiService.findShops(any));

      //ASSERT
      //verify that product was still added successfully
      verify(mockDatabaseService.addProduct(any)).called(1);

      //verify UI was still updated successfully
      expect(productProvider.products.length, 1);
      expect(productProvider.products.first.name, productName);

      //verify that the app attempted to call the ApiService
      verify(mockApiService.findShops(any)).called(1);

      //(Implicit) The test will fail if an unhandled exception is thrown.
    });
  });

  group('Input validation and normalization', () {
    setUp(() {
      productProvider = ProductProvider(
        dbService: mockDatabaseService,
        api: mockApiService,
        location: mockLocationService,
      );
      when(mockDatabaseService.getProducts()).thenAnswer((_) async => []);
    });

    test('addProduct should not add a duplicate product (case-insensitive)', () async {
      //ARRANGE
      final existingProduct = Product(id: 1, name: 'Test Coffee');
      when(mockDatabaseService.getProducts()).thenAnswer((_) async => [existingProduct]);

      final productProvider = ProductProvider(
        dbService: mockDatabaseService,
        api: mockApiService,
        location: mockLocationService,
      );
      await Future.delayed(Duration.zero);

      //ACT
      await productProvider.addProduct('test Coffee');

      //ASSERT
      verifyNever(mockDatabaseService.addProduct(any));
      expect(productProvider.products.length, 1);
    });

    test('addProduct should not add a duplicate product with diacritics', () async {
      //ARRANGE
      final existingProduct = Product(id: 1, name: 'paine');
      when(mockDatabaseService.getProducts()).thenAnswer((_) async => [existingProduct]);
      await productProvider.fetchProducts();

      //ACT
      await productProvider.addProduct('pâine');

      //ASSERT
      verifyNever(mockDatabaseService.addProduct(any));
      expect(productProvider.products.length, 1);
    });

    test('addProduct should not add a duplicate product with whitespace', () async {
      //ARRANGE
      final existingProduct = Product(id: 1, name: 'lapte');
      when(mockDatabaseService.getProducts()).thenAnswer((_) async => [existingProduct]);
      await productProvider.fetchProducts();

      //ACT
      await productProvider.addProduct('   lapte   ');

      //ASSERT
      verifyNever(mockDatabaseService.addProduct(any));
      expect(productProvider.products.length, 1);
    });

    test('addProduct should not add an empty or whitespace-only product', () async {
      //Arrange
      when(mockDatabaseService.getProducts()).thenAnswer((_) async => []);
      await productProvider.fetchProducts();

      //Act
      await productProvider.addProduct('   ');
      await productProvider.addProduct('');

      //Assert
      verifyNever(mockDatabaseService.addProduct(any));
      expect(productProvider.products, isEmpty);
    });

    test(
      'addProduct should not add a duplicate product with leading/trailing punctuation',
      () async {
        //ARRANGE
        final existingProduct = Product(id: 1, name: 'orez');

        when(
          mockDatabaseService.getProducts(),
        ).thenAnswer((_) async => [existingProduct]);
        await (productProvider.fetchProducts());

        //ACT
        await (productProvider.addProduct('orez!'));
        await (productProvider.addProduct('.orez'));
        await (productProvider.addProduct('..orez?,;'));

        //ASSERT
        verifyNever(mockDatabaseService.addProduct(any));
        expect(productProvider.products.length, 1);
      },
    );
  });
}
