import 'dart:core';
import 'dart:developer';

import 'package:buy_beacon/models/shop_location.dart';
import 'package:buy_beacon/services/location_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart' as bg;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../utils/location_utils.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<StatefulWidget> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late GoogleMapController mapController;

  @override
  void initState() {
    super.initState();
    Provider.of<LocationService>(context, listen: false).getCurrentLocation();
  }

  Set<Marker> _createShopMarkers(
    List<ShopLocation> allLocations,
    Set<String> activeGeofenceIdentifiers,
    bg.Location? userLocation,
  ) {
    log(
      '[MapScreen] _addShopMarkers started with ${allLocations.length} locations.',
      name: 'MapScreen',
    );
    final Set<Marker> markers = {};
    final List<ShopLocation> activeLocations = allLocations
        .where(
          (shop) => activeGeofenceIdentifiers.contains(
            'shop_${shop.latitude}_${shop.longitude}',
          ),
        )
        .toList();
    ShopLocation? closestActiveShop;
    double minDistance = double.infinity;

    if (userLocation != null) {
      for (var shop in activeLocations) {
        final LatLng shopLatLng = LatLng(shop.latitude, shop.longitude);
        final userLatLng = LatLng(
          userLocation.coords.latitude,
          userLocation.coords.longitude,
        );
        final distance = calculateDistance(userLatLng, shopLatLng);
        if (distance < minDistance) {
          minDistance = distance;
          closestActiveShop = shop;
        }
      }
    }
    for (var shop in activeLocations) {
      final LatLng shopLatLng = LatLng(shop.latitude, shop.longitude);
      double distance = 0.0;
      String distanceSnippet = 'Distance unknown';
      if (userLocation != null) {
        final userLatLng = LatLng(
          userLocation.coords.latitude,
          userLocation.coords.longitude,
        );
        distance = calculateDistance(userLatLng, shopLatLng);
        distanceSnippet = '${(distance / 1000).toStringAsFixed(2)} km away';
        log(
          '[MapScreen] Calculated distance for'
          '${shop.name}:'
          '${distance.toStringAsFixed(2)}'
          'meters',
          name: 'MapScreen',
        );
      } else {
        log(
          '[MapScreen] _userLocation is null, cannot calculate distance for'
          '${shop.name}.',
          name: 'MapScreen',
        );
      }

      String productsDisplayString = shop.products.join(', ');
      if (productsDisplayString.length > 500) {
        productsDisplayString = '${productsDisplayString.substring(0, 500)}...';
      }
      final String productSnippet = shop.products.isNotEmpty
          ? productsDisplayString
          : 'No products listed';

      log(
        '[MapScreen] productSnippet length for ${shop.name}: ${productSnippet.length}',
        name: 'MapScreen',
      );
      log(
        '[MapScreen] Final productSnippet for ${shop.name}: "$productSnippet"',
        name: 'MapScreen',
      );

      BitmapDescriptor markerColor;
      if (closestActiveShop != null &&
          shop.latitude == closestActiveShop.latitude &&
          shop.longitude == closestActiveShop.longitude) {
        markerColor = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
      } else {
        markerColor = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow);
      }
      markers.add(
        Marker(
          markerId: MarkerId(shop.name),
          position: shopLatLng,
          infoWindow: InfoWindow(
            title: shop.name,
            snippet: '$distanceSnippet - $productSnippet',
          ),
          icon: markerColor,
        ),
      );
    }
    log(
      '[MapScreen] _createShopMarkers finished. Total markers: ${markers.length}',
      name: 'MapScreen',
    );
    return markers;
  }

  void _onMapCreated(GoogleMapController gMController) {
    mapController = gMController;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LocationService>(
      builder: (context, locationService, child) {
        final userLocation = locationService.userLocation;
        LatLng initialCameraPosition;

        if (userLocation != null) {
          initialCameraPosition = LatLng(
            userLocation.coords.latitude,
            userLocation.coords.longitude,
          );
        } else {
          initialCameraPosition = const LatLng(44.4267674, 26.1025384);
        }

        if (userLocation != null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Nearest Shops')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final Set<Marker> currentMarkers = _createShopMarkers(
          locationService.monitoredShopLocations,
          locationService.activeGeofenceIdentifiers,
          userLocation,
        );

        return Scaffold(
          appBar: AppBar(title: const Text('Nearest Shops')),
          body: GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: initialCameraPosition,
              zoom: 15.0,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            markers: currentMarkers,
          ),
        );
      },
    );
  }
}
