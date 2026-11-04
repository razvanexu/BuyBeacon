import 'package:buy_beacon/models/app_geofence_event.dart';
import 'package:buy_beacon/models/app_location.dart';
import 'package:buy_beacon/models/shop_location.dart';
import 'package:buy_beacon/services/geofence_service.dart';
import 'package:buy_beacon/services/geofence_state_store.dart';
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

class InMemoryGeofenceStateStore extends GeofenceStateStore {
  Map<String, DateTime> saved = {};

  @override
  Future<Map<String, DateTime>> load() async => Map.of(saved);

  @override
  Future<void> save(Map<String, DateTime> lastInsideAt) async {
    saved = Map.of(lastInsideAt);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GeofenceService geofenceService;
  late MockLocationService mockLocationService;
  late MockTraceletPlatform mockPlatform;
  late InMemoryGeofenceStateStore stateStore;

  setUp(() {
    mockLocationService = MockLocationService();
    when(mockLocationService.getCurrentLocation()).thenAnswer(
      (_) async =>
          const AppLocation(latitude: 1.0, longitude: 1.0, accuracy: 10.0, isMoving: false),
    );
    when(mockLocationService.userLocation).thenReturn(null);
    stateStore = InMemoryGeofenceStateStore();
    geofenceService = GeofenceService(
      locationService: mockLocationService,
      stateStore: stateStore,
    );

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

        //ACT: 2nd confirming location update (a new fix) -> ENTER fires.
        when(mockLocationService.userLocation).thenReturn(
          const AppLocation(latitude: 1.00001, longitude: 1.0, accuracy: 5.0, isMoving: false),
        );
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

        //ACT: 2nd confirming location update (a new fix) -> EXIT fires.
        when(mockLocationService.userLocation).thenReturn(
          const AppLocation(latitude: 10.00001, longitude: 10.0, accuracy: 5.0, isMoving: false),
        );
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
        when(mockLocationService.userLocation).thenReturn(
          const AppLocation(latitude: 1.00001, longitude: 1.0, accuracy: 10.0, isMoving: false),
        );
        listener();
        await Future<void>.delayed(Duration.zero);
        expect(events, hasLength(1));
        expect(events.single.action, GeofenceAction.enter);

        // Jitter out to ~545m (the stationary jitter seen in the 2026-11-04
        // walk log) for 2 checks in a row -- exit threshold = 500m +
        // max(40, 75) = 575m, so this stays inside even after confirmation.
        when(mockLocationService.userLocation).thenReturn(
          const AppLocation(
            latitude: 1.004901,
            longitude: 1.0,
            accuracy: 40.0,
            isMoving: false,
          ),
        );
        listener();
        await Future<void>.delayed(Duration.zero);
        when(mockLocationService.userLocation).thenReturn(
          const AppLocation(
            latitude: 1.004902,
            longitude: 1.0,
            accuracy: 40.0,
            isMoving: false,
          ),
        );
        listener();
        await Future<void>.delayed(Duration.zero);
        expect(events, hasLength(1), reason: 'jitter within the hysteresis buffer should not exit');

        // A real, sustained move to ~600m -- beyond the buffer, confirmed
        // over 2 checks -> exits.
        when(mockLocationService.userLocation).thenReturn(
          const AppLocation(
            latitude: 1.005396,
            longitude: 1.0,
            accuracy: 40.0,
            isMoving: false,
          ),
        );
        listener();
        await Future<void>.delayed(Duration.zero);
        expect(events, hasLength(1), reason: 'a single check should not be enough to confirm EXIT');
        when(mockLocationService.userLocation).thenReturn(
          const AppLocation(
            latitude: 1.005397,
            longitude: 1.0,
            accuracy: 40.0,
            isMoving: false,
          ),
        );
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

        //ACT: now a real, sustained approach -- 2 consecutive confirming fixes.
        when(mockLocationService.userLocation).thenReturn(
          const AppLocation(latitude: 1.00001, longitude: 1.0, accuracy: 5.0, isMoving: false),
        );
        listener();
        await Future<void>.delayed(Duration.zero);
        when(mockLocationService.userLocation).thenReturn(
          const AppLocation(latitude: 1.00002, longitude: 1.0, accuracy: 5.0, isMoving: false),
        );
        listener();
        await Future<void>.delayed(Duration.zero);

        //ASSERT
        expect(events, hasLength(1));
        expect(events.single.action, GeofenceAction.enter);
      },
    );

    AppLocation fixAt(double latitude, int second) => AppLocation(
      latitude: latitude + second * 0.000001,
      longitude: 1.0,
      accuracy: 5.0,
      isMoving: false,
      timestamp: DateTime.utc(2026, 11, 4, 6, 0, second),
    );

    Future<void> settle() => Future<void>.delayed(Duration.zero);

    test('the same fix checked twice does not count as two confirmations', () async {
      await geofenceService.initialize();
      final listener =
          verify(mockLocationService.addListener(captureAny)).captured.single
              as void Function();
      final events = <AppGeofenceEvent>[];
      geofenceService.onGeofenceEvent.listen(events.add);

      // addGeofences checks the current fix, then the same fix arrives again
      // through the listener -- one real fix, not two.
      when(mockLocationService.userLocation).thenReturn(fixAt(1.0, 1));
      await geofenceService.addGeofences([
        ShopLocation(name: 'Shop 1', latitude: 1.0, longitude: 1.0, products: []),
      ]);
      listener();
      await settle();
      expect(events, isEmpty);

      when(mockLocationService.userLocation).thenReturn(fixAt(1.0, 2));
      listener();
      await settle();
      expect(events.single.action, GeofenceAction.enter);
    });

    test('the same position re-emitted with a new timestamp does not count twice', () async {
      await geofenceService.initialize();
      final listener =
          verify(mockLocationService.addListener(captureAny)).captured.single
              as void Function();
      final events = <AppGeofenceEvent>[];
      geofenceService.onGeofenceEvent.listen(events.add);

      // Seen on-device 2026-11-04 10:27:55-56: three records, new timestamps,
      // bit-identical coordinates and accuracy.
      AppLocation reEmitted(int second) => AppLocation(
        latitude: 1.0,
        longitude: 1.0,
        accuracy: 11.42,
        isMoving: false,
        timestamp: DateTime.utc(2026, 11, 4, 10, 27, second),
      );
      when(mockLocationService.userLocation).thenReturn(reEmitted(55));
      await geofenceService.addGeofences([
        ShopLocation(name: 'Shop 1', latitude: 1.0, longitude: 1.0, products: []),
      ]);
      when(mockLocationService.userLocation).thenReturn(reEmitted(56));
      listener();
      when(mockLocationService.userLocation).thenReturn(reEmitted(57));
      listener();
      await settle();

      expect(events, isEmpty);
    });

    test('a shop that drops out of one fetch does not re-fire ENTER when it comes back', () async {
      await geofenceService.initialize();
      final listener =
          verify(mockLocationService.addListener(captureAny)).captured.single
              as void Function();
      final events = <AppGeofenceEvent>[];
      geofenceService.onGeofenceEvent.listen(events.add);
      final shop = ShopLocation(name: 'Shop 1', latitude: 1.0, longitude: 1.0, products: []);
      final otherShop = ShopLocation(name: 'Shop 2', latitude: 5.0, longitude: 5.0, products: []);

      when(mockLocationService.userLocation).thenReturn(fixAt(1.0, 1));
      await geofenceService.addGeofences([shop]);
      when(mockLocationService.userLocation).thenReturn(fixAt(1.0, 2));
      listener();
      await settle();
      expect(events, hasLength(1));

      await geofenceService.addGeofences([otherShop]);
      await geofenceService.addGeofences([shop, otherShop]);
      when(mockLocationService.userLocation).thenReturn(fixAt(1.0, 3));
      listener();
      when(mockLocationService.userLocation).thenReturn(fixAt(1.0, 4));
      listener();
      await settle();

      expect(events, hasLength(1), reason: 'the user never left the shop');
    });

    test('after an app restart, shops the user was recently inside do not re-fire ENTER', () async {
      stateStore.saved = {'shop_1.0_1.0': DateTime.now().subtract(const Duration(minutes: 5))};
      await geofenceService.initialize();
      final listener =
          verify(mockLocationService.addListener(captureAny)).captured.single
              as void Function();
      final events = <AppGeofenceEvent>[];
      geofenceService.onGeofenceEvent.listen(events.add);

      when(mockLocationService.userLocation).thenReturn(fixAt(1.0, 1));
      await geofenceService.addGeofences([
        ShopLocation(name: 'Shop 1', latitude: 1.0, longitude: 1.0, products: []),
      ]);
      when(mockLocationService.userLocation).thenReturn(fixAt(1.0, 2));
      listener();
      await settle();

      expect(events, isEmpty);
    });

    test('inside state older than the memory window is not restored', () async {
      stateStore.saved = {'shop_1.0_1.0': DateTime.now().subtract(const Duration(hours: 2))};
      await geofenceService.initialize();
      final listener =
          verify(mockLocationService.addListener(captureAny)).captured.single
              as void Function();
      final events = <AppGeofenceEvent>[];
      geofenceService.onGeofenceEvent.listen(events.add);

      when(mockLocationService.userLocation).thenReturn(fixAt(1.0, 1));
      await geofenceService.addGeofences([
        ShopLocation(name: 'Shop 1', latitude: 1.0, longitude: 1.0, products: []),
      ]);
      when(mockLocationService.userLocation).thenReturn(fixAt(1.0, 2));
      listener();
      await settle();

      expect(events.single.action, GeofenceAction.enter);
    });

    test('ENTER and EXIT are persisted for the next app start', () async {
      await geofenceService.initialize();
      final listener =
          verify(mockLocationService.addListener(captureAny)).captured.single
              as void Function();

      when(mockLocationService.userLocation).thenReturn(fixAt(1.0, 1));
      await geofenceService.addGeofences([
        ShopLocation(name: 'Shop 1', latitude: 1.0, longitude: 1.0, products: []),
      ]);
      when(mockLocationService.userLocation).thenReturn(fixAt(1.0, 2));
      listener();
      await settle();
      expect(stateStore.saved.keys, contains('shop_1.0_1.0'));

      when(mockLocationService.userLocation).thenReturn(fixAt(1.01, 3));
      listener();
      when(mockLocationService.userLocation).thenReturn(fixAt(1.01, 4));
      listener();
      await settle();
      expect(stateStore.saved, isEmpty);
    });
  });
}
