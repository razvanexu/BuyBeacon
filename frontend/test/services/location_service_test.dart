import 'package:buy_beacon/services/location_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:tracelet_platform_interface/tracelet_platform_interface.dart';

import 'location_service_test.mocks.dart';

@GenerateMocks([], customMocks: [MockSpec<TraceletPlatform>(as: #GeneratedMockTraceletPlatform)])
class MockTraceletPlatform extends GeneratedMockTraceletPlatform with MockPlatformInterfaceMixin {}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocationService locationService;
  late MockTraceletPlatform mockPlatform;

  setUp(() {
    locationService = LocationService();
    mockPlatform = MockTraceletPlatform();
    TraceletPlatform.instance = mockPlatform;
  });

  Map<String, Object?> mockLocationMap(double lat, double lon) {
    return {
      'coords': {'latitude': lat, 'longitude': lon, 'accuracy': 1.0},
      'timestamp': DateTime.now().toIso8601String(),
      'uuid': 'mock-location-uuid',
      'is_moving': false,
    };
  }

  test('getCurrentLocation updates userLocation and notifies listeners', () async {
    // ARRANGE
    final newLocationMap = mockLocationMap(50.0, 50.0);
    when(mockPlatform.getCurrentPosition(any)).thenAnswer((_) async => newLocationMap);

    int listenerCallCount = 0;
    locationService.addListener(() => listenerCallCount++);

    // ACT
    final result = await locationService.getCurrentLocation();

    // ASSERT
    expect(result?.latitude, 50.0);
    expect(result?.longitude, 50.0);
    expect(locationService.userLocation?.latitude, 50.0);
    expect(listenerCallCount, 1);
  });

  test('stopTracking disables restart on boot before stopping tracking', () async {
    when(mockPlatform.setConfig(any)).thenAnswer((_) async => {'enabled': true});
    when(mockPlatform.stop()).thenAnswer((_) async => {'enabled': false});

    await locationService.stopTracking();

    final calls = verifyInOrder([mockPlatform.setConfig(captureAny), mockPlatform.stop()]);
    final config = calls.first.captured.single as TlConfig;
    expect(config.app.startOnBoot, isFalse);
  });

  test('stopTracking still stops tracking when the config update fails', () async {
    when(mockPlatform.setConfig(any)).thenThrow(Exception('config failed'));
    when(mockPlatform.stop()).thenAnswer((_) async => {'enabled': false});

    await locationService.stopTracking();

    verify(mockPlatform.stop()).called(1);
  });
}
