import 'dart:developer';

import 'package:buy_beacon/orchestrators/shopping_orchestrator.dart';
import 'package:buy_beacon/providers/product_provider.dart';
import 'package:buy_beacon/repositories/product_repository.dart';
import 'package:buy_beacon/screens/map_screen.dart';
import 'package:buy_beacon/services/geofence_service.dart';
import 'package:buy_beacon/services/location_service.dart';
import 'package:buy_beacon/services/notification_channel_service.dart';
import 'package:buy_beacon/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void onNotificationTap(NotificationResponse response) {
  log(
    '[onNotificationTap] Notification tapped with payload: ${response.payload}',
    name: 'MyAppMain',
  );
  navigatorKey.currentState?.push(
    MaterialPageRoute(builder: (context) => const MapScreen()),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  log('[main] App starting...', name: 'MyAppMain');
  final channelService = NotificationChannelService();

  final notificationService = NotificationService();

  final locationService = LocationService();

  final productRepository = ProductRepository();

  final productProvider = ProductProvider(productRepository: productRepository);

  final geofenceService = GeofenceService(
    notificationService: notificationService,
    locationService: locationService,
  );

  final shoppingOrchestrator = ShoppingOrchestrator(
    productProvider: productProvider,
    productRepository: productRepository,
    geofenceService: geofenceService,
  );
  log('[main] ShoppingOrchestrator created.', name: 'MyAppMain');

  runApp(
    MultiProvider(
      providers: [
        Provider<ShoppingOrchestrator>(create: (_) => shoppingOrchestrator, lazy: false),
        ChangeNotifierProvider.value(value: locationService),
        ChangeNotifierProvider.value(value: productProvider),
        ChangeNotifierProvider.value(value: geofenceService),
      ],
      child: const BuyBeaconApp(),
    ),
  );

  await notificationService.initialize(
    onNotificationTap: onNotificationTap,
    channels: channelService.notificationChannels,
  );
  log('[main] NotificationService initialized.', name: 'MyAppMain');

  await locationService.initialize(
    channel: NotificationChannelService.androidForegroundServiceChannel,
  );
  log('[main] LocationService initialized.', name: 'MyAppMain');

  geofenceService.initialize();
  log('[main] GeofenceService initialized.', name: 'MyAppMain');

  log('[main] Initialization complete. Running app...', name: 'MyAppMain');

  try {
    log('[main] Loading initial product data...', name: 'MyAppMain');
    await productProvider.loadInitialData();
    log('[main] Initial product data LOADED.', name: 'MyAppMain');
  } catch (e, s) {
    log(
      '[main] ERROR loading initial product data: $e',
      name: 'MyAppMain',
      error: e,
      stackTrace: s,
    );
  }
}

class BuyBeaconApp extends StatelessWidget {
  const BuyBeaconApp({super.key});

  @override
  Widget build(BuildContext context) {
    log('[BuyBeaconApp] Build method called.', name: 'MyAppMain');
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'BuyBeacon',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const HomeScreen(),
    );
  }
}
