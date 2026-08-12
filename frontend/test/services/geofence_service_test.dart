import 'package:buy_beacon/models/shop_location.dart';
import 'package:buy_beacon/services/geofence_service.dart';
import 'package:buy_beacon/services/location_service.dart';
import 'package:buy_beacon/services/notification_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart' as bg;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'geofence_service_test.mocks.dart';

@GenerateMocks([NotificationService, LocationService])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GeofenceService geofenceService;
  late MockLocationService mockLocationService;

  const MethodChannel channel = MethodChannel(
    'com.transistorsoft/flutter_background_geolocation/methods',
  );

  setUp(() {
    mockLocationService = MockLocationService();
    when(mockLocationService.getCurrentLocation()).thenAnswer((_) async {
      return bg.Location({
        'uuid': 'test-uuid',
        'timestamp': DateTime.now().toIso8601String(),
        'is_moving': false,
        'odometer': 0.0,
        'age': 0,
        'event': 'motionchange',
        'coords': {
          'latitude': 1.0,
          'longitude': 1.0,
          'accuracy': 10.0,
          'speed': 0.0,
          'heading': 0.0,
          'altitude': 0.0,
          'ellipsoidal_altitude': 0.0
        },
        'activity': {'type': 'still', 'confidence': 100},
        'battery': {'is_charging': false, 'level': 1.0},
      });
    });
    geofenceService = GeofenceService(
      // notificationService: mockNotificationService,
      locationService: mockLocationService,
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          return true;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('GeofenceService', () {
    test('initialize should clear all native geofences from a previous session', () async {
      //ARRANGE
      final List<MethodCall> methodCallLog = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            methodCallLog.add(methodCall);
            return true;
          });

      //ACT
      await geofenceService.initialize();

      //ASSERT
      // Native geofences persist across app restarts, but the in-memory diff cache
      // (_geofenceData) doesn't -- without an explicit clear on startup, geofences from a
      // previous session would never be detected as stale and would pile up indefinitely.
      expect(methodCallLog.map((call) => call.method), contains('removeGeofences'));
    });

    test('addGeofences should clear old geofences and add new ones', () async {
      //ARRANGE
      final locations = [
        ShopLocation(name: 'Shop 1', latitude: 1.0, longitude: 1.0, products: []),
      ];

      final List<MethodCall> methodCallLog = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            methodCallLog.add(methodCall);
            return true;
          });

      //ACT
      await geofenceService.addGeofences(locations);

      //ASSERT
      // With diff-based logic: starting from empty state, only addGeofence is called.
      expect(methodCallLog.length, 1);
      expect(methodCallLog[0].method, 'addGeofence');
      expect(methodCallLog[0].arguments, isA<Map>());
      expect(methodCallLog.map((call) => call.method).toList(), ['addGeofence']);
    });
  });
}
