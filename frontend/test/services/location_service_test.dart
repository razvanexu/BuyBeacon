import 'package:buy_beacon/services/location_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart' as bg;
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocationService locationService;
  bg.Location? mockCurrentLocation;

  const MethodChannel channel = MethodChannel(
    'com.transistorsoft/flutter_background_geolocation/methods',
  );

  setUp(() {
    locationService = LocationService();
    mockCurrentLocation = null;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          switch (methodCall.method) {
            case 'ready':
              return {'enabled': true};
            case 'start':
              return {'enabled': true};
            case 'getCurrentPosition':
              if (mockCurrentLocation != null) {
                return mockCurrentLocation!.map;
              }
              return null;
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

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

  test('getCurrentLocation updates userLocation and notifies listeners', () async {
    // ARRANGE
    final newLocation = createMockLocation(50.0, 50.0);
    mockCurrentLocation = newLocation;

    int listenerCallCount = 0;
    locationService.addListener(() => listenerCallCount++);

    // ACT
    final result = await locationService.getCurrentLocation();

    // ASSERT
    expect(result?.uuid, newLocation.uuid);
    expect(locationService.userLocation?.uuid, newLocation.uuid);
    expect(listenerCallCount, 1);
  });
}
