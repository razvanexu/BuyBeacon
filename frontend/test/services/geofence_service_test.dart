import 'package:buy_beacon/models/app_geofence_event.dart';
import 'package:buy_beacon/models/app_location.dart';
import 'package:buy_beacon/models/shop_location.dart';
import 'package:buy_beacon/services/geofence_service.dart';
import 'package:buy_beacon/services/location_service.dart';
import 'package:buy_beacon/services/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:tracelet_platform_interface/tracelet_platform_interface.dart'
    hide GeofenceAction;

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
    when(mockLocationService.userLocation).thenReturn(null);
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

    test(
      'addGeofences fires a software ENTER when the shop is already within '
      'radius, after 2 confirming location updates',
      () async {
        //ARRANGE
        await geofenceService.initialize();
        final listener =
            verify(mockLocationService.addListener(captureAny)).captured.single
                as void Function();
        final events = <AppGeofenceEvent>[];
        geofenceService.onGeofenceEvent.listen(events.add);

        when(mockLocationService.userLocation).thenReturn(
          const AppLocation(latitude: 1.0, longitude: 1.0, accuracy: 5.0, isMoving: false),
        );

        //ACT: user is already standing on top of the shop when it's registered
        // -- this is the 1st confirming check, so no event fires yet.
        await geofenceService.addGeofences([
          ShopLocation(name: 'Shop 1', latitude: 1.0, longitude: 1.0, products: []),
        ]);
        await Future<void>.delayed(Duration.zero);
        expect(events, isEmpty, reason: 'a single check should not be enough to confirm ENTER');

        //ACT: 2nd confirming location update -> ENTER fires.
        listener();
        await Future<void>.delayed(Duration.zero);

        //ASSERT
        expect(events, hasLength(1));
        expect(events.single.action, GeofenceAction.enter);
        expect(geofenceService.activeGeofenceIdentifiers, contains('shop_1.0_1.0'));

        //ACT: user walks far away -- 1st confirming check, no EXIT yet.
        when(mockLocationService.userLocation).thenReturn(
          const AppLocation(latitude: 10.0, longitude: 10.0, accuracy: 5.0, isMoving: false),
        );
        listener();
        await Future<void>.delayed(Duration.zero);
        expect(events, hasLength(1), reason: 'a single check should not be enough to confirm EXIT');

        //ACT: 2nd confirming location update -> EXIT fires.
        listener();
        await Future<void>.delayed(Duration.zero);

        //ASSERT
        expect(events, hasLength(2));
        expect(events.last.action, GeofenceAction.exit);
        expect(geofenceService.activeGeofenceIdentifiers, isEmpty);
      },
    );

    test(
      'EXIT uses an accuracy-scaled hysteresis buffer so GPS jitter near the '
      'boundary does not flap',
      () async {
        //ARRANGE
        await geofenceService.initialize();
        final listener =
            verify(mockLocationService.addListener(captureAny)).captured.single
                as void Function();
        final events = <AppGeofenceEvent>[];
        geofenceService.onGeofenceEvent.listen(events.add);

        //ACT: confirm ENTER with 2 checks right on top of the shop.
        when(mockLocationService.userLocation).thenReturn(
          const AppLocation(latitude: 1.0, longitude: 1.0, accuracy: 10.0, isMoving: false),
        );
        await geofenceService.addGeofences([
          ShopLocation(name: 'Shop 1', latitude: 1.0, longitude: 1.0, products: []),
        ]);
        await Future<void>.delayed(Duration.zero);
        listener();
        await Future<void>.delayed(Duration.zero);
        expect(events, hasLength(1));
        expect(events.single.action, GeofenceAction.enter);

        // Jitter out to ~510m with a noisy fix (accuracy 40m) for 2 checks in
        // a row -- exit threshold = 500m + max(40, 30) = 540m, so this stays
        // inside even after confirmation.
        when(mockLocationService.userLocation).thenReturn(
          const AppLocation(
            latitude: 1.004582,
            longitude: 1.0,
            accuracy: 40.0,
            isMoving: false,
          ),
        );
        listener();
        await Future<void>.delayed(Duration.zero);
        listener();
        await Future<void>.delayed(Duration.zero);
        expect(events, hasLength(1), reason: 'jitter within the hysteresis buffer should not exit');

        // A real, sustained move to ~550m -- beyond the buffer, confirmed
        // over 2 checks -> exits.
        when(mockLocationService.userLocation).thenReturn(
          const AppLocation(
            latitude: 1.004940,
            longitude: 1.0,
            accuracy: 40.0,
            isMoving: false,
          ),
        );
        listener();
        await Future<void>.delayed(Duration.zero);
        expect(events, hasLength(1), reason: 'a single check should not be enough to confirm EXIT');
        listener();
        await Future<void>.delayed(Duration.zero);
        expect(events, hasLength(2));
        expect(events.last.action, GeofenceAction.exit);
      },
    );

    test(
      'a single stray fix does not flip an ENTER/EXIT transition, but a '
      'sustained one does',
      () async {
        //ARRANGE
        await geofenceService.initialize();
        final listener =
            verify(mockLocationService.addListener(captureAny)).captured.single
                as void Function();
        final events = <AppGeofenceEvent>[];
        geofenceService.onGeofenceEvent.listen(events.add);

        when(mockLocationService.userLocation).thenReturn(
          const AppLocation(latitude: 10.0, longitude: 10.0, accuracy: 5.0, isMoving: false),
        );
        await geofenceService.addGeofences([
          ShopLocation(name: 'Shop 1', latitude: 1.0, longitude: 1.0, products: []),
        ]);
        await Future<void>.delayed(Duration.zero);

        //ACT: one stray fix lands right on the shop (1st confirming check)...
        when(mockLocationService.userLocation).thenReturn(
          const AppLocation(latitude: 1.0, longitude: 1.0, accuracy: 5.0, isMoving: false),
        );
        listener();
        await Future<void>.delayed(Duration.zero);
        expect(events, isEmpty);

        // ...then jumps back out before a 2nd confirming check ever happens.
        when(mockLocationService.userLocation).thenReturn(
          const AppLocation(latitude: 10.0, longitude: 10.0, accuracy: 5.0, isMoving: false),
        );
        listener();
        await Future<void>.delayed(Duration.zero);

        //ASSERT: never confirmed, so no ENTER fired.
        expect(events, isEmpty);

        //ACT: now a real, sustained approach -- 2 consecutive confirming checks.
        when(mockLocationService.userLocation).thenReturn(
          const AppLocation(latitude: 1.0, longitude: 1.0, accuracy: 5.0, isMoving: false),
        );
        listener();
        await Future<void>.delayed(Duration.zero);
        listener();
        await Future<void>.delayed(Duration.zero);

        //ASSERT
        expect(events, hasLength(1));
        expect(events.single.action, GeofenceAction.enter);
      },
    );
  });
}
