import 'package:buy_beacon/models/app_location.dart';
import 'package:buy_beacon/models/shop_location.dart';
import 'package:buy_beacon/services/geofence_service.dart';
import 'package:buy_beacon/services/location_service.dart';
import 'package:buy_beacon/services/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:tracelet_platform_interface/tracelet_platform_interface.dart';

import 'geofence_service_test.mocks.dart';

@GenerateMocks(
  [NotificationService, LocationService],
  customMocks: [MockSpec<TraceletPlatform>(as: #GeneratedMockTraceletPlatform)],
)
class MockTraceletPlatform extends GeneratedMockTraceletPlatform
    with MockPlatformInterfaceMixin {}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GeofenceService geofenceService;
  late MockLocationService mockLocationService;
  late MockTraceletPlatform mockPlatform;

  setUp(() {
    mockLocationService = MockLocationService();
    when(mockLocationService.getCurrentLocation()).thenAnswer(
      (_) async =>
          const AppLocation(latitude: 1.0, longitude: 1.0, accuracy: 10.0, isMoving: false),
    );
    geofenceService = GeofenceService(locationService: mockLocationService);

    mockPlatform = MockTraceletPlatform();
    when(mockPlatform.geofenceEvents).thenAnswer((_) => const Stream.empty());
    when(mockPlatform.addGeofence(any)).thenAnswer((_) async => true);
    when(mockPlatform.removeGeofence(any)).thenAnswer((_) async => true);
    when(mockPlatform.removeGeofences()).thenAnswer((_) async => true);
    TraceletPlatform.instance = mockPlatform;
  });

  group('GeofenceService', () {
    test('initialize should clear all native geofences from a previous session', () async {
      //ACT
      await geofenceService.initialize();

      //ASSERT
      // Native geofences persist across app restarts, but the in-memory diff cache
      // (_geofenceData) doesn't -- without an explicit clear on startup, geofences from a
      // previous session would never be detected as stale and would pile up indefinitely.
      verify(mockPlatform.removeGeofences()).called(1);
    });

    test('addGeofences should clear old geofences and add new ones', () async {
      //ARRANGE
      final locations = [
        ShopLocation(name: 'Shop 1', latitude: 1.0, longitude: 1.0, products: []),
      ];

      //ACT
      await geofenceService.addGeofences(locations);

      //ASSERT
      // With diff-based logic: starting from empty state, only addGeofence is called.
      verify(mockPlatform.addGeofence(any)).called(1);
      verifyNever(mockPlatform.removeGeofence(any));
    });
  });
}
