import 'dart:async';

import 'package:location/location.dart';
import 'package:geocoding/geocoding.dart' as gcode;
import 'package:google_maps_flutter/google_maps_flutter.dart' as map;


class LocationService {
  Location location = Location();
  bool _serviceEnabled = false;
  PermissionStatus? _permissionGranted;

  LocationData? currentLocation;

  Future<LocationData?> getLocation({
    bool silent = false,
    bool fast = false,  
  }) async {
    if (fast && currentLocation != null) {
      return currentLocation;
    }

    _permissionGranted = await location.hasPermission();
    if (_permissionGranted == PermissionStatus.denied ||
        _permissionGranted == PermissionStatus.deniedForever) {
      if (silent) {
        return null;
      } else {
        _permissionGranted = await location.requestPermission();
        if (_permissionGranted != PermissionStatus.granted &&
            _permissionGranted != PermissionStatus.grantedLimited) {
          return null;
        }
      }
    }

    if (!silent) {
      _serviceEnabled = await location.serviceEnabled();
      if (!_serviceEnabled) {
        _serviceEnabled = await location.requestService();
      }
    }

    currentLocation =
        await location.getLocation().timeout(const Duration(seconds: 10));

    return currentLocation;
  }
  Future<gcode.Placemark> getAddressFromLatLang(map.LatLng latLng) async {
    var placemarks = await gcode.placemarkFromCoordinates(
      latLng.latitude,
      latLng.longitude,
    );
    return placemarks.first;
  }
}
