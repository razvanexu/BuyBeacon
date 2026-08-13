import 'dart:core';

import 'package:buy_beacon/models/app_location.dart';
import 'package:buy_beacon/models/shop_location.dart';
import 'package:buy_beacon/orchestrators/shopping_orchestrator.dart';
import 'package:buy_beacon/orchestrators/shopping_state.dart';
import 'package:buy_beacon/services/location_service.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../utils/location_utils.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // Markers within this radius are shown at all -- shops further away aren't
  // relevant enough to clutter the map with. Kept in sync with the notification
  // geofence radius (GeofenceService.addGeofences) only for the "yellow" tier;
  // this outer radius is purely a display concern.
  static const double _nearRadiusMeters = 500;
  static const double _visibleRadiusMeters = 1000;

  GoogleMapController? _mapController;

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  void _updateCameraPosition(AppLocation? userLocation) {
    if (_mapController == null || userLocation == null) return;

    _mapController?.animateCamera(
      CameraUpdate.newLatLng(LatLng(userLocation.latitude, userLocation.longitude)),
    );
  }

  Set<Marker> _createShopMarkers(
    List<ShopLocation> allLocations,
    AppLocation? userLocation,
  ) {
    final Set<Marker> markers = {};
    if (userLocation == null || allLocations.isEmpty) {
      return markers;
    }

    final userLatLng = LatLng(userLocation.latitude, userLocation.longitude);

    // Distance-based, computed directly rather than relying on native geofence
    // ENTER/EXIT events: those drive notifications (see NotificationDecisionService,
    // unchanged) but are too slow/inconsistent to also drive map rendering -- on a
    // fixed/simulated location they may never fire for most nearby shops at all.
    final shopsWithDistance = allLocations
        .map(
          (shop) => (
            shop: shop,
            distance: calculateDistance(
              userLatLng,
              LatLng(shop.latitude, shop.longitude),
            ),
          ),
        )
        .where((entry) => entry.distance <= _visibleRadiusMeters)
        .toList();

    if (shopsWithDistance.isEmpty) {
      return markers;
    }

    final closest = shopsWithDistance.reduce((a, b) => a.distance < b.distance ? a : b);

    for (final entry in shopsWithDistance) {
      final shop = entry.shop;
      final distance = entry.distance;
      final distanceSnippet = '${(distance / 1000).toStringAsFixed(2)} km away';

      String productsDisplayString = shop.products.join(', ');
      if (productsDisplayString.length > 200) {
        productsDisplayString = '${productsDisplayString.substring(0, 200)}...';
      }
      final String productSnippet = shop.products.isNotEmpty
          ? productsDisplayString
          : 'No products listed';

      final bool isClosest =
          shop.latitude == closest.shop.latitude &&
          shop.longitude == closest.shop.longitude;

      final double hue = isClosest
          ? BitmapDescriptor.hueGreen
          : (distance <= _nearRadiusMeters
                ? BitmapDescriptor.hueYellow
                : BitmapDescriptor.hueRed);

      markers.add(
        Marker(
          markerId: MarkerId(shop.name),
          position: LatLng(shop.latitude, shop.longitude),
          infoWindow: InfoWindow(
            title: shop.name,
            snippet: '$distanceSnippet - $productSnippet',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(hue),
        ),
      );
    }
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    // The top-level consumer listens for user location changes.
    return Consumer2<LocationService, ShoppingOrchestrator>(
      builder: (context, locationService, orchestrator, child) {
        final userLocation = locationService.userLocation;

        // Show a loading indicator until we have the user's location.
        if (userLocation == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Nearest Shops')),
            body: const Center(child: Text("Waiting for your location...")),
          );
        }

        _updateCameraPosition(userLocation);

        // Once we have the user's location, we build the map.
        // The StreamBuilder listens for shop location and loading state changes.
        return StreamBuilder<ShoppingState>(
          stream: orchestrator.onStateChanged,
          initialData: orchestrator.currentState, // Use current state for initial build
          builder: (context, snapshot) {
            final allShopLocations = snapshot.data?.shopLocations ?? [];
            final isLoading = snapshot.data?.isLoading ?? false;

            final initialCameraPosition = LatLng(userLocation.latitude, userLocation.longitude);

            final Set<Marker> currentMarkers = _createShopMarkers(
              allShopLocations,
              userLocation,
            );

            return Scaffold(
              appBar: AppBar(
                title: const Text('Nearest Shops'),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(4.0),
                  child: isLoading
                      ? const LinearProgressIndicator()
                      : const SizedBox.shrink(),
                ),
              ),
              body: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: initialCameraPosition,
                  zoom: 15.0,
                ),
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                markers: currentMarkers,
                onMapCreated: _onMapCreated,
              ),
            );
          },
        );
      },
    );
  }
}
