import 'package:flutter/services.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart' as bg;
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/shop_location.dart';
import 'package:frontend/services/location_service.dart';
import 'package:mockito/mockito.dart';

import '../providers/product_provider_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocationService locationService;
  late MockNotificationService mockNotificationService;

  const MethodChannel channel = MethodChannel(
    'com.transistorsoft/flutter_background_geolocation/methods',
  );

  setUp(() {
    mockNotificationService = MockNotificationService();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          if (methodCall.method == 'addGeofence' || methodCall.method == 'addGeofences') {
            return true;
          }

          if (methodCall.method == 'removeGeofences') {
            return true;
          }

          if (methodCall.method == 'ready') {
            return {'enabled': true};
          }
          return null;
        });

    locationService = LocationService.testable(
      notificationService: mockNotificationService,
    );

    when(mockNotificationService.initialize()).thenAnswer((_) async {});
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

  test(
    'onGeofence ENTER event should trigger a generic notification when no location data is cached',
    () async {
      // ARRANGE
      // Set up mock event return
      final geofenceEvent = createTestGeofenceEvent(
        identifier: 'unknown_geofence',
        action: 'ENTER',
      );

      // ACT
      // Manually call the private _onGeofence method with our fake event.
      // This requires making it public for testing.
      locationService.onGeofence(geofenceEvent);

      // ASSERT
      // Verify that showNotification was called exactly once.
      verify(
        mockNotificationService.showNotification(
          title: 'BuyBeacon reminder',
          body: 'You are near a store that might have an item on your list!',
          payload: 'unknown_geofence',
        ),
      ).called(1);
    },
  );

  test(
    'onGeofence ENTER event should trigger a specific notification when location data is cached',
    () async {
      //ARRANGE
      final shopLocation = ShopLocation(
        name: 'Test Shop',
        latitude: 45.0,
        longitude: -75.0,
        products: ['Coffee', 'Milk'],
      );
      final geofenceIdentifier =
          'shop_${shopLocation.latitude}_${shopLocation.longitude}';

      await locationService.addGeofences([shopLocation]);

      final geofenceEvent = createTestGeofenceEvent(
        identifier: geofenceIdentifier,
        action: 'ENTER',
        lat: shopLocation.latitude,
        lon: shopLocation.longitude,
      );

      //ACT
      locationService.onGeofence(geofenceEvent);

      //ASSERT
      verify(
        mockNotificationService.showNotification(
          title: 'BuyBeacon reminder',
          body: 'You are near Test Shop, which might have: Coffee, Milk',
          payload: geofenceIdentifier,
        ),
      ).called(1);
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
}
