import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/product.dart';
import 'package:frontend/models/shop_location.dart';
import 'package:frontend/providers/product_provider.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/services/database_service.dart';
import 'package:frontend/services/location_service.dart';
import 'package:frontend/services/notification_service.dart';
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
    // ARRANGE
    when(mockDatabaseService.getProducts()).thenAnswer((_) async => []);

    productProvider = ProductProvider(
      dbService: mockDatabaseService,
      api: mockApiService,
      location: mockLocationService,
    );
    await Future.delayed(Duration.zero);

    const productName = 'Test Coffee';
    final newProduct = Product(id: 1, name: productName);
    final shopLocation = ShopLocation(
      name: 'Coffee Place',
      latitude: 1.0,
      longitude: 1.0,
      products: [productName],
    );

    // Mock the sequence of events for adding a product.
    when(mockDatabaseService.addProduct(any)).thenAnswer((_) async => 1);
    // The second call to getProducts (after adding) should return the new list.
    when(mockDatabaseService.getProducts()).thenAnswer((_) async => [newProduct]);
    // When findShops is called with the new product list, return a location.
    when(mockApiService.findShops(any)).thenAnswer((_) async => [shopLocation]);

    //ACT
    await productProvider.addProduct(productName);

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
  });

  test(
    'deleteProduct should remove product, refetch list, and clear geofences',
    () async {
      //ARRANGE
      final productToDelete = Product(id: 1, name: 'Old Product');
      when(mockDatabaseService.getProducts()).thenAnswer((_) async => [productToDelete]);

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
    //ARRANGE
    when(mockDatabaseService.getProducts()).thenAnswer((_) async => []);

    final productProvider = ProductProvider(
      dbService: mockDatabaseService,
      api: mockApiService,
      location: mockLocationService,
    );
    await Future.delayed(Duration.zero);

    const productName = 'Network-Fail Product';
    final newProduct = Product(id: 1, name: productName);

    when(mockDatabaseService.addProduct(any)).thenAnswer((_) async => 1);
    when(mockDatabaseService.getProducts()).thenAnswer((_) async => [newProduct]);
    when(
      mockApiService.findShops(any),
    ).thenThrow(Exception('Network Error: 503 Service Unavailable'));

    //ACT
    await productProvider.addProduct(productName);

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
}
