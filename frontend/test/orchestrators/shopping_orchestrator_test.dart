import 'package:buy_beacon/models/product.dart';
import 'package:buy_beacon/models/shop_location.dart';
import 'package:buy_beacon/orchestrators/shopping_orchestrator.dart';
import 'package:buy_beacon/orchestrators/shopping_state.dart';
import 'package:buy_beacon/providers/product_provider.dart';
import 'package:buy_beacon/repositories/product_repository.dart';
import 'package:buy_beacon/services/geofence_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'shopping_orchestrator_test.mocks.dart';

@GenerateMocks([ProductRepository, GeofenceService])
void main() {
  late ShoppingOrchestrator orchestrator;
  late MockProductRepository mockProductRepository;
  late MockGeofenceService mockGeofenceService;
  late ProductProvider productProvider;

  setUp(() {
    mockProductRepository = MockProductRepository();
    mockGeofenceService = MockGeofenceService();
    productProvider = ProductProvider(productRepository: mockProductRepository);

    when(mockProductRepository.findShopsForProducts(any)).thenAnswer((_) async => []);
    when(mockGeofenceService.addGeofences(any)).thenAnswer((_) async {});

    orchestrator = ShoppingOrchestrator(
      productProvider: productProvider,
      productRepository: mockProductRepository,
      geofenceService: mockGeofenceService,
    );
  });

  tearDown(() {
    orchestrator.dispose();
  });

  group('Shopping Orchestrator', () {
    test('when products change should fetch shops and update geofences', () async {
      //ARRANGE
      final products = [Product(name: 'Test')];
      final shopLocations = [
        ShopLocation(name: 'Test Shop', latitude: 1.0, longitude: 1.0, products: []),
      ];

      when(mockProductRepository.getAllProducts()).thenAnswer((_) async => products);
      when(
        mockProductRepository.findShopsForProducts(any),
      ).thenAnswer((_) async => shopLocations);

      //ACT
      // &
      //ASSERT
      expect(
        orchestrator.onStateChanged,
        emitsInOrder([
          isA<ShoppingState>().having((s) => s.isLoading, 'isLoading', true),
          isA<ShoppingState>()
              .having((s) => s.isLoading, 'isLoading', false)
              .having((s) => s.shopLocations, 'shopLocations', isNotEmpty),
        ]),
      );
      //ACT
      productProvider.loadInitialData();
      await Future.delayed(Duration.zero);

      //ASSERT
      verify(mockProductRepository.findShopsForProducts(products)).called(1);
      verify(mockGeofenceService.addGeofences(any)).called(1);
    });

    test('when fetch fails, it emits an error state and schedules a retry', () async {
      //ARRANGE
      final products = [Product(name: 'Test')];
      when(mockProductRepository.getAllProducts()).thenAnswer((_) async => products);
      when(
        mockProductRepository.findShopsForProducts(any),
      ).thenThrow(Exception('Netwrk Error'));

      //ACT
      orchestrator.onStateChanged;
      emitsInOrder([isA<ShoppingState>().having((s) => s.isLoading, 'isLoading', true)]);

      await (productProvider.loadInitialData());

      await Future.delayed(Duration.zero);

      //ASSERT
      verify(mockProductRepository.findShopsForProducts(products)).called(1);
      verifyNever(mockGeofenceService.addGeofences(any));
    });
  });
}
