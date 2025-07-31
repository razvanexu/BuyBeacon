import 'dart:math';

import 'package:google_maps_flutter/google_maps_flutter.dart';

double calculateDistance(LatLng p1, LatLng p2) {
  const double earthRadius = 6371000;
  double lat1Rad = _degreesToRadians(p1.latitude);
  double lon1Rad = _degreesToRadians(p1.longitude);
  double lat2Rad = _degreesToRadians(p2.latitude);
  double lon2Rad = _degreesToRadians(p2.longitude);

  double dLat = lat2Rad - lat1Rad;
  double dLon = lon2Rad - lon1Rad;

  double a =
      sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1Rad) * cos(lat2Rad) * sin(dLon / 2) * sin(dLon / 2);
  double c = 2 * atan2(sqrt(a), sqrt(1 - a));

  return earthRadius * c;
}

double _degreesToRadians(double degrees) {
  return degrees * pi / 180;
}
