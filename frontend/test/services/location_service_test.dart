import 'package:buy_beacon/models/shop_location.dart';
import 'package:buy_beacon/services/location_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart' as bg;
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../providers/product_provider_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocationService locationService;
  late MockNotificationService mockNotificationService;
  bg.Location? mockCurrentLocation;

  const MethodChannel channel = MethodChannel(
    'com.transistorsoft/flutter_background_geolocation/methods',
  );

  void setupMockMethodCallHandler() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          switch (methodCall.method) {
            case 'addGeofence':
            case 'addGeofences':
            case 'removeGeofences':
              return true;
            case 'ready':
              return {'enabled': true};
            case 'getCurrentPosition': // Return the mock location if it's set, otherwise a default.
              if (mockCurrentLocation != null) {
                return mockCurrentLocation!.map;
              }
              return {
                'coords': {'latitude': 0.0, 'longitude': 0.0},
                'activity': {'type': 'still', 'confidence': 100},
                'battery': {'is_charging': false, 'level': 1.0},
                'timestamp': '2025-07-27T10:00:00Z',
                'uuid': 'default-uuid',
                'is_moving': false,
                'odometer': 0.0,
              };
            default:
              return null;
          }
        });
  }

  setUp(() {
    mockNotificationService = MockNotificationService();
    setupMockMethodCallHandler();

    locationService = LocationService.testable(
      notificationService: mockNotificationService,
    );

    mockCurrentLocation = null;
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  bg.GeofenceEvent createTestGeofenceEvent({
    required String identifier,
    required String action,
    double lat = 1.0,
    double lon = 1.0,
  }) {
    return bg.GeofenceEvent({
      'action': action,
      'identifier': identifier,
      'timestamp': '2025-07-21T12:00:00Z',
      'location': {
        'age': 1,
        'uuid': 'test-uuid-for-$identifier',
        'timestamp': '2025-07-20T12:00:00Z',
        'is_moving': false,
        'odometer': 0.0,
        'coords': {
          'latitude': lat,
          'longitude': lon,
          'ellipsoidal_altitude': 1.0,
          'accuracy': 10.0,
          'altitude': 0.0,
          'heading': 0.0,
          'speed': 0.0,
        },
        'activity': {'type': 'still', 'confidence': 100},
        'battery': {'is_charging': false, 'level': 1.0},
        'geofence': {
          'identifier': identifier,
          'action': action,
          'radius': 500,
          'extras': {},
        },
      },
    });
  }

  bg.Location createMockLocation(double lat, double lon) {
    return bg.Location({
      'coords': {
        'latitude': lat,
        'longitude': lon,
        'accuracy': 1.0,
        'altitude': 0.0,
        'heading': 0.0,
        'speed': 0.0,
        'ellipsoidal_altitude': 0.0,
      },
      'activity': {'type': 'still', 'confidence': 100},
      'age': 0,
      'battery': {'is_charging': false, 'level': 1.0},
      'timestamp': DateTime.now().toIso8601String(),
      'uuid': 'mock-location-uuid',
      'is_moving': false,
      'odometer': 0.0,
    });
  }

  test(
    'onGeofence ENTER should trigger notification ONLY if it is the nearest shop',
    () async {
      // ARRANGE
      // 2 shops, near and far
      final nearShop = ShopLocation(
        name: 'Near Shop',
        latitude: 10.0,
        longitude: 10.0,
        products: ['A'],
      );
      final farShop = ShopLocation(
        name: 'Far Shop',
        latitude: 20.0,
        longitude: 20.0,
        products: ['B'],
      );
      await locationService.addGeofences([nearShop, farShop]);

      mockCurrentLocation = createMockLocation(10.001, 10.001);

      final geofenceEvent = createTestGeofenceEvent(
        identifier: 'shop_${nearShop.latitude}_${nearShop.longitude}',
        action: 'ENTER',
        lat: nearShop.latitude,
        lon: nearShop.longitude,
      );

      // ACT
      // Manually call the private _onGeofence method with our fake event.
      // This requires making it public for testing.
      await locationService.onGeofence(geofenceEvent);

      // ASSERT
      // Verify that showNotification was called exactly once.
      verify(
        mockNotificationService.showNotification(
          title: 'BuyBeacon reminder',
          body: 'You are near Near Shop which might have A',
          payload: 'Near Shop',
        ),
      ).called(1);
    },
  );

  test(
    'onGeofence ENTER should NOT trigger notification if it is NOT the nearest shop',
    () async {
      //ARRANGE
      // 2 shops, near and far
      final nearShop = ShopLocation(
        name: 'Near Shop',
        latitude: 10.0,
        longitude: 10.0,
        products: ['A'],
      );
      final farShop = ShopLocation(
        name: 'Far Shop',
        latitude: 20.0,
        longitude: 20.0,
        products: ['B'],
      );
      await locationService.addGeofences([nearShop, farShop]);

      final geofenceIdentifier = 'shop_${farShop.latitude}_${farShop.longitude}';

      mockCurrentLocation = createMockLocation(10.001, 10.001);

      final geofenceEvent = createTestGeofenceEvent(
        identifier: geofenceIdentifier,
        action: 'ENTER',
        lat: farShop.latitude,
        lon: farShop.longitude,
      );

      //ACT
      await locationService.onGeofence(geofenceEvent);

      //ASSERT
      verifyNever(
        mockNotificationService.showNotification(
          title: 'BuyBeacon reminder',
          body: 'You are near Far Shop, which might have: B',
          payload: geofenceIdentifier,
        ),
      );
    },
  );

  test(
    'onGeofence ENTER adds identifier to active list and notifies listeners',
    () async {
      //ARRANGE
      final shop = ShopLocation(
        name: 'Test Shop',
        latitude: 1.0,
        longitude: 1.0,
        products: [],
      );
      final geofenceIdentifier = 'shop_${shop.latitude}_${shop.longitude}';
      await locationService.addGeofences([shop]);
      mockCurrentLocation = createMockLocation(1.0, 1.0);

      final geofenceEvent = createTestGeofenceEvent(
        identifier: geofenceIdentifier,
        action: 'ENTER',
      );
      int listenerCallCount = 0;
      locationService.addListener(() => listenerCallCount++);

      //ACT
      await locationService.onGeofence(geofenceEvent);

      //ASSERT
      expect(locationService.activeGeofenceIdentifiers, contains(geofenceIdentifier));
      expect(listenerCallCount, 1);
    },
  );

  test('onGeofence OTHER event (e.g., EXIT) should NOT trigger a notification', () async {
    //ARRANGE
    //test opposite case ('EXIT')
    final geofenceEvent = createTestGeofenceEvent(
      identifier: 'any_geofence',
      action: 'EXIT',
    );

    //ACT
    locationService.onGeofence(geofenceEvent);

    //ASSERT
    //Verify 'showNotification' was never called
    verifyNever(
      mockNotificationService.showNotification(
        title: anyNamed('title'),
        body: anyNamed('body'),
        payload: anyNamed('payload'),
      ),
    );
  });

  test(
    'onGeofence EXIT removes identifier from active list and notifies listeners',
    () async {
      //ARRANGE
      final shop = ShopLocation(
        name: 'Test shop',
        latitude: 1.0,
        longitude: 1.0,
        products: [],
      );
      final geofenceIdentifier = 'shop_${shop.latitude}_${shop.longitude}';
      locationService.activeGeofenceIdentifiers.add(geofenceIdentifier);

      final geofenceEvent = createTestGeofenceEvent(
        identifier: geofenceIdentifier,
        action: 'EXIT',
      );
      int listenerCallCount = 0;
      locationService.addListener(() => listenerCallCount++);

      //ACT
      locationService.onGeofence(geofenceEvent);

      //ASSERT
      expect(
        locationService.activeGeofenceIdentifiers,
        isNot(contains(geofenceIdentifier)),
      );
      expect(listenerCallCount, 1);
    },
  );

  test('clearGeofences should also clear active geofence identifiers', () async {
    //ARRANGE
    locationService.activeGeofenceIdentifiers.add('some_active_geofence');
    int listenerCallCount = 0;
    locationService.addListener(() => listenerCallCount++);

    //ACT
    await locationService.clearGeoFences();

    //ASSERT
    expect(locationService.activeGeofenceIdentifiers, isEmpty);
    expect(listenerCallCount, 1);
  });

  test('_onLocation updates userLocation and notifies listeners', () {
    //ARRANGE
    final newLocation = createMockLocation(50.0, 50.0);
    int listereCallCount = 0;
    locationService.addListener(() => listereCallCount++);

    //ACT
    locationService.onLocation(newLocation);

    //ASSERT
    expect(locationService.userLocation, newLocation);
    expect(listereCallCount, 1);
  });
}
