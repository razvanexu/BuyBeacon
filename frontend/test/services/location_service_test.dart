import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/location_service.dart';
import 'package:mockito/mockito.dart';

import '../providers/product_provider_test.mocks.dart';


void main(){
  late LocationService locationService;
  late MockNotificationService mockNotificationService;
  late MockGeofenceEvent mockGeofenceEvent;
  
  setUp((){
    mockNotificationService = MockNotificationService();
    mockGeofenceEvent = MockGeofenceEvent();

    locationService = LocationService.testable(
      notificationService: mockNotificationService
    );

    when(mockNotificationService.initialize()).thenAnswer((_) async {});
  });

  test('onGeofence ENTER event should trigger a notification', () async {
    // ARRANGE
    // Set up mock event return
    when(mockGeofenceEvent.action).thenReturn('ENTER');
    when(mockGeofenceEvent.identifier).thenReturn('test_geofence_1');

    // ACT
    // Manually call the private _onGeofence method with our fake event.
    // This requires making it public for testing.
    locationService.onGeofence(mockGeofenceEvent);

    // ASSERT
    // Verify that showNotification was called exactly once.
    verify(mockNotificationService.showNotification(
      title: 'BuyBeacon reminder',
      body: anyNamed('body'),
      payload: 'test_geofence_1'
    )).called(1);
  });

  test('onGeofence OTHER event should NOT trigger a notification', () async {
    //ARRANGE
    //test opposite case ('EXIT')
    when(mockGeofenceEvent.action).thenReturn('EXIT');

    //ACT
    locationService.onGeofence(mockGeofenceEvent);

    //ASSERT
    //Verify 'showNotification' was never called
    verifyNever(mockNotificationService.showNotification(
        title: anyNamed('title'),
        body: anyNamed('body'),
        payload: anyNamed('payload')
    ));
  });
}