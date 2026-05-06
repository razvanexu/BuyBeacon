import 'dart:collection';
import 'dart:developer';

import 'package:buy_beacon/models/product.dart';
import 'package:buy_beacon/models/shop_location.dart';
import 'package:buy_beacon/orchestrators/shopping_orchestrator.dart';
import 'package:buy_beacon/orchestrators/shopping_state.dart';
import 'package:buy_beacon/providers/product_provider.dart';
import 'package:buy_beacon/repositories/product_repository.dart';
import 'package:buy_beacon/services/geofence_service.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'shopping_orchestrator_test.mocks.dart';

@GenerateMocks([ProductRepository, GeofenceService])
void main() {
  late ShoppingOrchestrator orchestrator;
  late MockProductRepository mockProductRepository;
  late MockGeofenceService mockGeofenceService;
  late CustomMockProductProvider customMockProductProvider;

  setUp(() {
    log('TEST_DEBUG: setUp START');
    mockProductRepository = MockProductRepository();
    log('TEST_DEBUG: setUp - mockProductRepository created');
    mockGeofenceService = MockGeofenceService();
    log('TEST_DEBUG: setUp - mockGeofenceService created');
    customMockProductProvider = CustomMockProductProvider();
    log('TEST_DEBUG: setUp - customMockProductProvider created');

    when(
      mockProductRepository.getAllProducts(),
    ).thenAnswer((_) async => customMockProductProvider.productsInternal);
    log('TEST_DEBUG: setUp - getAllProducts STUBBED');
    when(mockProductRepository.findShopsForProducts(any)).thenAnswer((_) async => []);
    log('TEST_DEBUG: setUp - findShopsForProducts STUBBED');
    when(mockGeofenceService.addGeofences(any)).thenAnswer((_) async {});
    log('TEST_DEBUG: setUp - addGeofences STUBBED');

    log('TEST_DEBUG: setUp - ABOUT TO CREATE ShoppingOrchestrator');
    orchestrator = ShoppingOrchestrator(
      productProvider: customMockProductProvider,
      productRepository: mockProductRepository,
      geofenceService: mockGeofenceService,
    );
    log('TEST_DEBUG: setUp - ShoppingOrchestrator CREATED');
    log('TEST_DEBUG: setUp END');
  });

  tearDown(() {
    orchestrator.dispose();
  });

  group('Shopping Orchestrator', () {
    test('when products change should fetch shops and update geofences', () async {
      // ARRANGE
      final products = [Product(name: 'Test Product X')]; // Use a unique name for clarity
      final shopLocations = [
        ShopLocation(
          name: 'Test Shop X',
          latitude: 1.0,
          longitude: 1.0,
          products: products.map((p) => p.name).toList(),
        ),
      ];
      final customProductProvider = customMockProductProvider;
      customProductProvider.productsInternal =
          products; // So productProvider.products is correct



      // Stub for the call we are verifying (findShopsForProducts)
      when(mockProductRepository.findShopsForProducts(products)).thenAnswer((_) async {
        log(
          'Test: mockProductRepository.findShopsForProducts() was called.',
          name: '[TestFlow]',
        );
        return shopLocations;
      });
      // Stub for the geofence call
      when(mockGeofenceService.addGeofences(shopLocations)).thenAnswer((_) async {
        log('Test: mockGeofenceService.addGeofences() was called.', name: '[TestFlow]');
      });

      expectLater(
        orchestrator.onStateChanged,
        emitsInOrder([
          isA<ShoppingState>().having((s) => s.isLoading, 'isLoading', true),
          isA<ShoppingState>()
              .having((s) => s.isLoading, 'isLoading', false)
              .having((s) => s.shopLocations, 'shopLocations', shopLocations),
          // Expect specific locations
        ]),
      );

      // ACT
      log(
        'Test: Calling customProductProvider.triggerOnProductsChanged() to start the action.',
        name: '[TestFlow]',
      );
      customProductProvider.triggerOnProductsChanged(); // Directly trigger the listener

      // Wait for the expected calls to complete.
      // untilCalled is very helpful for debugging async mock interactions.

      await untilCalled(mockProductRepository.findShopsForProducts(products));
      await untilCalled(mockGeofenceService.addGeofences(shopLocations));

      // ASSERT


      // This is line 74 in your original file structure:
      verify(mockProductRepository.findShopsForProducts(products)).called(1);
      verify(mockGeofenceService.addGeofences(shopLocations)).called(1);
    });

    test('when fetch fails, it emits an error state and eventually retries successfully', () {
      // Use fakeAsync to control Timers
      fakeAsync((async) {
        // ARRANGE
        final products = [Product(name: 'Test')];
        final successfulShopLocations = [
          ShopLocation(
            name: 'Retry Shop',
            latitude: 1.0,
            longitude: 1.0,
            products: products.map((p) => p.name).toList(),
          ),
        ];

        // Initial product load (triggers _onProductsChanged and thus _fetchProductsAndShops)
        when(mockProductRepository.getAllProducts()).thenAnswer((_) async => products);

        // --- First attempt: Fail ---
        when(
          mockProductRepository.findShopsForProducts(products),
        ).thenThrow(Exception('Network Error'));

        // --- Setup expectations for state changes ---
        expectLater(
          orchestrator.onStateChanged,
          // map to ensure distinct states for emitsInOrder
          emitsInOrder([
            // State 1: Initial loading
            isA<ShoppingState>()
                .having((s) => s.isLoading, 'isLoading', true)
                .having((s) => s.hasConnectionError, 'hasError', false)
                .having((s) => s.shopLocations, 'shopLocations', isEmpty),
            // State 2: Fails, error state
            isA<ShoppingState>()
                .having((s) => s.isLoading, 'isLoading', false)
                .having((s) => s.hasConnectionError, 'hasError', true)
                .having((s) => s.shopLocations, 'shopLocations', isEmpty),
            // State 3: Retry attempt starts (isLoading true again)
            isA<ShoppingState>()
                .having((s) => s.isLoading, 'isLoading', true)
                .having((s) => s.hasConnectionError, 'hasError', false),
            // Error should be cleared by new attempt
            // State 4: Retry succeeds
            isA<ShoppingState>()
                .having((s) => s.isLoading, 'isLoading', false)
                .having((s) => s.hasConnectionError, 'hasError', false)
                .having((s) => s.shopLocations, 'shopLocations', successfulShopLocations),
          ]),
        );

        // ACT: Trigger the initial fetch by calling the orchestrator's onProductsChanged callback
        orchestrator.onStateChanged; // Ensure stream is listened to before events.
        orchestrator.currentState; // Access current state to initialize if needed.
        // This simulates the initial state before product changes.

        // Simulate ProductProvider notifying orchestrator after loading products
        customMockProductProvider.productsInternal =
            products; // Assuming a way to set products for the test
        customMockProductProvider.triggerOnProductsChanged(); // Simulate the callback

        // Allow microtasks to complete for the first fetch attempt and error emission
        async.elapse(Duration.zero);

        // VERIFY: First attempt calls and failure
        verify(mockProductRepository.findShopsForProducts(products)).called(1);
        verifyNever(mockGeofenceService.addGeofences(any));

        // --- ARRANGE for successful retry ---
        when(
          mockProductRepository.findShopsForProducts(products),
        ).thenAnswer((_) async => successfulShopLocations);
        when(mockGeofenceService.addGeofences(any)).thenAnswer((_) async => {});

        // ACT: Advance the timer for the first retry attempt

        log(
          'Advancing timer by 60 seconds for the first retry attempt...',
          name: '[ShoppingOrchestratorTest]',
        );
        async.elapse(const Duration(seconds: 60));

        // Allow microtasks for the retry to complete
        async.elapse(Duration.zero); // or async.elapse(Duration.zero);

        // VERIFY: Second attempt (retry) calls and success
        verify(
          mockProductRepository.findShopsForProducts(products),
        ).called(1); // Called once more (the retry)
        verify(
          mockGeofenceService.addGeofences(successfulShopLocations),
        ).called(1); // Now called on success

        when(
          mockProductRepository.findShopsForProducts(products),
        ).thenThrow(Exception('Should not be called again'));
        async.elapse(const Duration(hours: 2)); // Elapse well past max retry
        verifyNever(mockProductRepository.findShopsForProducts(any)); // No more retries after success
      }); // End of fakeAsync
    });
  });
}

class CustomMockProductProvider extends Mock implements ProductProvider {
  List<Product> productsInternal = [];
  bool _isInitialized = false;
  void Function()?
  _onProductsChangedCallback; // Stores the callback from ShoppingOrchestrator

  @override
  UnmodifiableListView<Product> get products => UnmodifiableListView(productsInternal);

  @override
  bool get isInitialized => _isInitialized;

  void setInitialized(bool initialized) {
    _isInitialized = initialized;
  }

  @override
  set onProductsChanged(void Function()? callback) {
    _onProductsChangedCallback = callback; // ShoppingOrchestrator passes its method here
    log(
      'CustomMockProductProvider: onProductsChanged callback set.',
      name: '[TestSetup]',
    );
  }

  @override
  void Function()? get onProductsChanged => _onProductsChangedCallback;

  // Call this in your test's ACT phase
  void triggerOnProductsChanged() {
    log(
      'CustomMockProductProvider: triggerOnProductsChanged called.',
      name: '[TestSetup]',
    );
    if (_onProductsChangedCallback != null) {
      _onProductsChangedCallback!(); // This executes ShoppingOrchestrator._onProductsChanged
    } else {
      log(
        'CustomMockProductProvider: WARNING - triggerOnProductsChanged called but no callback was set!',
        name: '[TestSetup]',
      );
    }
  }

  @override
  Future<void> loadInitialData() async {
    setInitialized(true);
    // If your actual ProductProvider.loadInitialData calls onProductsChanged, simulate that:
    // log('CustomMockProductProvider: loadInitialData triggering onProductsChanged.', name: '[TestSetup]');
    // triggerOnProductsChanged();
  }

  @override
  Future<void> addProduct(String name) async {
    /* Mock if needed */
  }

  @override
  Future<void> deleteProduct(int productId) async {
    /* Mock if needed */
  }
}
