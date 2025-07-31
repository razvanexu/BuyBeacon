import 'package:buy_beacon/providers/product_provider.dart';
import 'package:buy_beacon/screens/map_screen.dart';
import 'package:buy_beacon/services/location_service.dart';
import 'package:buy_beacon/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void onNotificationTap(NotificationResponse response) {
  navigatorKey.currentState?.push(
    MaterialPageRoute(builder: (context) => const MapScreen()),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().initialize(onNotificationTap: onNotificationTap);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => LocationService()),
      ],
      child: const BuyBeaconApp(),
    ),
  );
}

class BuyBeaconApp extends StatelessWidget {
  const BuyBeaconApp({super.key});

  @override
  Widget build(BuildContext context) {
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
