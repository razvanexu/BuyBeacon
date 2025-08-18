import 'dart:core';

import 'package:buy_beacon/models/shop_location.dart';
import 'package:buy_beacon/orchestrators/shopping_orchestrator.dart';
import 'package:buy_beacon/orchestrators/shopping_state.dart';
import 'package:buy_beacon/services/geofence_service.dart';
import 'package:buy_beacon/services/location_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart' as bg;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../utils/location_utils.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  void _updateCameraPosition(bg.Location? userLocation) {
    if (_mapController != null && userLocation?.coords != null) return;

    _mapController?.animateCamera(
      CameraUpdate.newLatLng(
        LatLng(userLocation!.coords.latitude, userLocation.coords.longitude),
      ),
    );
  }

  Set<Marker> _createShopMarkers(
    List<ShopLocation> allLocations,
    Set<String> activeGeofenceIdentifiers,
    bg.Location? userLocation,
  ) {
    final Set<Marker> markers = {};
    if (userLocation == null || allLocations.isEmpty) {
      return markers;
    }

    final activeLocations = allLocations.where((shop) {
      final identifier = 'shop_${shop.latitude}_${shop.longitude}';
      return activeGeofenceIdentifiers.contains(identifier);
    }).toList();

    if (activeLocations.isEmpty) {
      return markers;
    }

    final userLatLng = LatLng(
      userLocation.coords.latitude,
      userLocation.coords.longitude,
    );
    ShopLocation? closestShop;
    double minDistance = double.infinity;

    for (var shop in activeLocations) {
      final shopLatLng = LatLng(shop.latitude, shop.longitude);
      final distance = calculateDistance(userLatLng, shopLatLng);
      if (distance < minDistance) {
        minDistance = distance;
        closestShop = shop;
      }
    }

    for (var shop in activeLocations) {
      final shopLatLng = LatLng(shop.latitude, shop.longitude);
      final distance = calculateDistance(userLatLng, shopLatLng);
      final distanceSnippet = '${(distance / 1000).toStringAsFixed(2)} km away';

      String productsDisplayString = shop.products.join(', ');
      if (productsDisplayString.length > 200) {
        productsDisplayString = '${productsDisplayString.substring(0, 200)}...';
      }
      final String productSnippet = shop.products.isNotEmpty
          ? productsDisplayString
          : 'No products listed';

      final bool isClosest =
          shop.latitude == closestShop?.latitude &&
          shop.longitude == closestShop?.longitude;

      markers.add(
        Marker(
          markerId: MarkerId(shop.name),
          position: shopLatLng,
          infoWindow: InfoWindow(
            title: shop.name,
            snippet: '$distanceSnippet - $productSnippet',
          ),
          icon: isClosest
              ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)
              : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
        ),
      );
    }
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    // The top-level consumer listens for user location changes.
    return Consumer3<LocationService, GeofenceService, ShoppingOrchestrator>(
      builder: (context, locationService, geofenceService, orchestrator, child) {
        final userLocation = locationService.userLocation;
        final activeIdentifiers = geofenceService.activeGeofenceIdentifiers;

        // Show a loading indicator until we have the user's location.
        if (userLocation?.coords == null) {
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

            final initialCameraPosition = LatLng(
              userLocation!.coords.latitude,
              userLocation.coords.longitude,
            );

            final Set<Marker> currentMarkers = _createShopMarkers(
              allShopLocations,
              activeIdentifiers,
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
