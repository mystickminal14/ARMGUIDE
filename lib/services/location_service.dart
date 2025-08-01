import 'package:geolocator/geolocator.dart';

class LocationService {
  static Future<(double, double)> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are denied.');
      }
    }

    Position position =
    await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    return (position.latitude, position.longitude);
  }
}