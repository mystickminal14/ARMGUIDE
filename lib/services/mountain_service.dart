import 'dart:math' as math;
import '../model/mountain.dart';

class MountainService {
  static final List<Mountain> mountains = [
    Mountain(name: "Everest", latitude: 27.9881, longitude: 86.9250, elevation: 8848.86),
    Mountain(name: "Kanchenjunga", latitude: 27.7029, longitude: 88.1467, elevation: 8586),
    Mountain(name: "Lhotse", latitude: 27.9616, longitude: 86.9333, elevation: 8516),
    Mountain(name: "Makalu", latitude: 27.8897, longitude: 87.0888, elevation: 8485),
    Mountain(name: "Cho Oyu", latitude: 28.0942, longitude: 86.6607, elevation: 8188),
    Mountain(name: "Dhaulagiri I", latitude: 28.6967, longitude: 83.4875, elevation: 8167),
    Mountain(name: "Manaslu", latitude: 28.5494, longitude: 84.5597, elevation: 8163),
    Mountain(name: "Annapurna I", latitude: 28.5961, longitude: 83.8203, elevation: 8091),
  ];

  static List<Map<String, dynamic>> getVisibleMountains({
    required double userLat,
    required double userLon,
    required double azimuth,
    required double pitch,
  }) {
    const double fov = 60.0;
    final List<Map<String, dynamic>> visible = [];

    for (var mountain in mountains) {
      final bearing = _calculateBearing(userLat, userLon, mountain.latitude, mountain.longitude);
      double diff = (azimuth - bearing).abs();
      if (diff > 180) diff = 360 - diff;

      if (diff < fov / 2) {
        double distance = _calculateDistance(userLat, userLon, mountain.latitude, mountain.longitude);
        visible.add({
          'name': mountain.name,
          'bearing': bearing,
          'distance': distance,
          'data': mountain,
        });
      }
    }

    return visible;
  }

  static double _calculateBearing(double lat1, double lon1, double lat2, double lon2) {
    double dLon = _degToRad(lon2 - lon1);
    double lat1Rad = _degToRad(lat1);
    double lat2Rad = _degToRad(lat2);

    double y = math.sin(dLon) * math.cos(lat2Rad);
    double x = math.cos(lat1Rad) * math.sin(lat2Rad) -
        math.sin(lat1Rad) * math.cos(lat2Rad) * math.cos(dLon);

    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  static double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371;
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(_degToRad(lat1)) * math.cos(_degToRad(lat2)) * math.pow(math.sin(dLon / 2), 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  static double _degToRad(double deg) => deg * math.pi / 180;
}
