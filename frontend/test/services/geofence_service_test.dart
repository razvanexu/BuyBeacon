import 'package:buy_beacon/models/shop_location.dart';
import 'package:buy_beacon/services/geofence_service.dart';
import 'package:buy_beacon/services/location_service.dart';
import 'package:buy_beacon/services/notification_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';

import 'geofence_service_test.mocks.dart';

@GenerateMocks([NotificationService, LocationService])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GeofenceService geofenceService;
  late MockNotificationService mockNotificationService;
  late MockLocationService mockLocationService;

  const MethodChannel channel = MethodChannel(
    'com.transistorsoft/flutter_background_geolocation/methods',
  );

  setUp(() {
    mockLocationService = MockLocationService();
    mockNotificationService = MockNotificationService();
    geofenceService = GeofenceService(
      notificationService: mockNotificationService,
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
      expect(methodCallLog.length, 2);
      expect(methodCallLog[0].method, 'removeGeofences');
      expect(methodCallLog[1].method, 'addGeofence');
      expect(methodCallLog[1].arguments, isA<Map>());
      expect(methodCallLog.map((call) => call.method).toList(), [
        'removeGeofences',
        'addGeofence',
      ]);
    });
  });
}
